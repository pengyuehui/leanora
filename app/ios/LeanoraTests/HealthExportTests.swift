import XCTest
@testable import Leanora

final class HealthExportTests: XCTestCase, @unchecked Sendable {
    func testMealRepeatedThreeTimesThenEditedHasOneSamplePerKnownComponent() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        var entry = DietEntry(meal: .lunch, nutrients: Nutrients(energyKcal: 300, proteinGrams: 20))
        let service = HealthExportService(repository: repository, transport: transport)
        try await repository.saveDiet(entry, catalog: [])
        for _ in 0..<3 { try await service.run() }
        let initial = await transport.all(); XCTAssertEqual(initial.count, 2)
        entry.nutrients.proteinGrams = nil; entry.nutrients.energyKcal = 350
        try await repository.saveDiet(entry, catalog: []); try await service.run()
        let edited = await transport.all(); XCTAssertEqual(edited.count, 1); XCTAssertEqual(edited.first?.value, 350)
        XCTAssertEqual(edited.first?.syncVersion, 2)
    }
    func testPartialAuthorizationLeavesOnlyFailedComponentAndStopCancelsNewJobs() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport(); await transport.allow([.energy])
        let entry = DietEntry(meal: .lunch, nutrients: Nutrients(energyKcal: 300, proteinGrams: 20)); try await repository.saveDiet(entry, catalog: [])
        try await HealthExportService(repository: repository, transport: transport).run()
        let jobs = try await repository.healthMetadata().compactMap { if case .job(let v) = $0 { return v }; return nil }
        XCTAssertEqual(jobs.count, 1); XCTAssertEqual(jobs.first?.component, .protein); XCTAssertNotNil(jobs.first?.errorCategory)
        var config = try await repository.healthConfiguration(); config.enabled = false; try await repository.configureHealth(config)
        try await repository.saveMeasurement(BodyMeasurement(metric: .weightKg, value: 70))
        let remaining = try await repository.healthMetadata().filter { if case .job = $0 { return true }; return false }; XCTAssertTrue(remaining.isEmpty)
    }
    func testBodyFatAndPausedWorkoutNeverInventCalories() throws {
        let m = BodyMeasurement(metric: .bodyFatPercent, value: 20)
        XCTAssertEqual(try HealthSampleMapper.export(.measurement(m), component: .bodyFat, version: 1, source: "own")?.value, 0.2)
        guard case .session(var session) = DataFixtures.records().first(where: { $0.kind == "session" }) else { return XCTFail() }
        session.pauses = [PauseInterval(startedAt: session.started.instant.addingTimeInterval(100), endedAt: session.started.instant.addingTimeInterval(200))]
        let sample = try HealthSampleMapper.export(.session(session), component: .workout, version: 1, source: "own")!
        XCTAssertEqual(sample.duration, 1700); XCTAssertNil(sample.value); XCTAssertEqual(sample.activity, "strength")
    }
    func testHealthSuccessBeforeLocalConfirmationRetriesIdempotently() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        try await repository.saveMeasurement(BodyMeasurement(metric: .weightKg, value: 66))
        await transport.failNextConfirmation(repository)
        let service = HealthExportService(repository: repository, transport: transport)
        try await service.run(); try await service.run()
        let values = await transport.all(), counts = await transport.counts()
        XCTAssertEqual(values.count, 1); XCTAssertEqual(counts.writes, 1)
        let jobs = try await repository.healthMetadata().filter { if case .job = $0 { return true }; return false }; XCTAssertTrue(jobs.isEmpty)
    }
    func testReplacementDeletionDoesNotSuppressNewVersionButManualRemovalDoes() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        var measurement = BodyMeasurement(metric: .weightKg, value: 70); try await repository.saveMeasurement(measurement)
        let engine = HealthSyncEngine(repository: repository, transport: transport); await engine.run()
        measurement.value = 71; try await repository.saveMeasurement(measurement); await engine.run(); await engine.run()
        let before = try await repository.healthMetadata(); XCTAssertFalse(before.contains { if case .suppression = $0 { return true }; return false })
        let sample = await transport.all().first!; await transport.remove(sample.id); await engine.run()
        measurement.stamp.revision = 2; measurement.value = 72; try await repository.saveMeasurement(measurement); await engine.run()
        let values = await transport.all(); XCTAssertTrue(values.isEmpty)
        let local = try await repository.snapshot(); XCTAssertTrue(local.contains { $0.id == measurement.stamp.id && $0.stamp.deletedAt == nil })
    }
    func testRestoreHoldsHistoryAndReconciliationCannotOverwriteNewerHealthVersion() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        let m = BodyMeasurement(metric: .weightKg, value: 65); try await repository.saveMeasurement(m)
        let backup = try await repository.exportBackup()
        var health = try HealthSampleMapper.export(.measurement(m), component: .weight, version: 10, source: transport.sourceBundleID)!; health.value = 80; await transport.seed([health])
        let prepared = try await repository.prepareImport(backup.data); _ = try await repository.importBackup(prepared, acceptNewer: true)
        let exporter = HealthExportService(repository: repository, transport: transport); try await exporter.reconcile(); try await exporter.run()
        let unchanged = await transport.all(); XCTAssertEqual(unchanged.first?.value, 80)
        // Only a deliberate history-export action raises above Health's floor.
        try await repository.enqueueHealthHistory(); try await exporter.run()
        let exported = await transport.all(); XCTAssertEqual(exported.count, 1); XCTAssertEqual(exported.first?.syncVersion, 11); XCTAssertEqual(exported.first?.value, 65)
    }
    func testLocalDeleteRequiresSeparateHealthCopyChoice() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        let m = BodyMeasurement(metric: .weightKg, value: 70); try await repository.saveMeasurement(m)
        let exporter = HealthExportService(repository: repository, transport: transport); try await exporter.run()
        try await repository.deleteMeasurement(m.stamp.id, revision: 1); try await exporter.run()
        let kept = await transport.all(); XCTAssertEqual(kept.count, 1)
        let other = BodyMeasurement(metric: .weightKg, value: 72); try await repository.saveMeasurement(other); try await exporter.run()
        var config = try await repository.healthConfiguration(); config.enabled = false; try await repository.configureHealth(config)
        try await repository.deleteMeasurement(other.stamp.id, revision: 1, deleteHealthCopies: true); try await exporter.run()
        let after = await transport.all(); XCTAssertEqual(after.count, 1)
    }
    func testUnknownComponentAfterUnconfirmedWriteStillDeletesHealthValue() async throws {
        let repository = try await HealthFixtures.repository(writing: [.protein]), transport = HealthTestTransport()
        var entry = DietEntry(meal: .lunch, nutrients: Nutrients(energyKcal: 100, proteinGrams: 20))
        try await repository.saveDiet(entry, catalog: []); await transport.failNextConfirmation(repository)
        let service = HealthExportService(repository: repository, transport: transport); try await service.run()
        entry.nutrients.proteinGrams = nil; try await repository.saveDiet(entry, catalog: []); try await service.run()
        let values = await transport.all(); XCTAssertTrue(values.isEmpty)
    }
}
