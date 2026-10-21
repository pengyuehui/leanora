import XCTest
@testable import Leanora

final class HealthSyncRecoveryTests: XCTestCase, @unchecked Sendable {
    func testEditAndObserverSignalDuringWriteConvergeToLatestVersion() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        var measurement = BodyMeasurement(metric: .weightKg, value: 60); try await repository.saveMeasurement(measurement)
        let engine = HealthSyncEngine(repository: repository, transport: transport)
        await transport.blockNextWrite()
        let first = Task { await engine.run() }
        await transport.waitForBlockedWrite()
        measurement.value = 61; try await repository.saveMeasurement(measurement)
        await engine.run() // Coalesces, rather than losing this observer signal.
        await transport.releaseWrite(); await first.value; await engine.waitUntilIdle()
        let values = await transport.all(), jobs = try await repository.healthJobs()
        XCTAssertEqual(values.count, 1); XCTAssertEqual(values.first?.value, 61); XCTAssertEqual(values.first?.syncVersion, 2); XCTAssertTrue(jobs.isEmpty)
    }
    func testWaitForBackgroundWriterBeforeHealthCleanupPreventsResurrection() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        try await repository.saveMeasurement(BodyMeasurement(metric: .weightKg, value: 60))
        let engine = HealthSyncEngine(repository: repository, transport: transport)
        await transport.blockNextWrite(); let first = Task { await engine.run() }; await transport.waitForBlockedWrite()
        var config = try await repository.healthConfiguration(); config.enabled = false; try await repository.configureHealth(config)
        let cleanup = Task { await engine.waitUntilIdle(); try await transport.deleteAllOwn() }
        await transport.releaseWrite(); await first.value; try await cleanup.value
        let values = await transport.all(); XCTAssertTrue(values.isEmpty)
    }
    func testOverlapAssociationChoosesOneDurationWithoutSummingCalories() async throws {
        let repository = try await HealthFixtures.repository()
        try await repository.save(DataFixtures.records().filter { $0.kind != "profile" })
        guard case .session(let local) = try await repository.snapshot().first(where: { $0.kind == "session" }) else { return XCTFail() }
        let external = ExternalWorkout(sampleUUID: UUID(), sourceBundleID: "watch.example", started: RecordMoment(local.started.instant.addingTimeInterval(60)), endedAt: local.endedAt!, activityType: "running", energyKcal: 300, distanceMeters: 2000, durationSeconds: 1440)
        let cursor = HealthImportCursor(installationID: UUID(), sampleType: "workout", queryStart: local.started.instant)
        try await repository.commitHealthImport([.workout(external)], cursor: cursor)
        let choice = HealthWorkoutAssociation(sampleUUID: external.sampleUUID, businessID: local.stamp.id, primary: .health)
        try await repository.associateHealthWorkout(choice)
        let stored = try await repository.healthRuntimeValue("association:\(external.sampleUUID)"); XCTAssertEqual(stored, .association(choice))
        XCTAssertEqual(HealthAggregation.primaryDuration(local: local, external: external, choice: .health), 1440)
        XCTAssertEqual(HealthAggregation.primaryDuration(local: local, external: external, choice: .local), 1800)
        XCTAssertEqual(TrainingSummary(sessions: [local]).volumeKg, 160)
        var unrelated = external; unrelated.started = RecordMoment(local.endedAt!.addingTimeInterval(1)); unrelated.endedAt = unrelated.started.instant.addingTimeInterval(60)
        XCTAssertFalse(HealthAggregation.overlaps(local, unrelated))
    }
}
