import XCTest
import SwiftData
@testable import Leanora

@MainActor final class PersistenceTests: XCTestCase {
    func testDiskReopenRetainsEveryIDAndSnapshots() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let records = DataFixtures.records()
        try await write(records, to: directory)
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let saved = try await reopened.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(saved), try RecordCoding.fingerprint(records))
        XCTAssertEqual(saved.flatMap(\.nestedIDs).sorted { $0.uuidString < $1.uuidString }, records.flatMap(\.nestedIDs).sorted { $0.uuidString < $1.uuidString })
    }

    private func write(_ records: [BusinessRecord], to directory: URL) async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        try await actor.save(records)
    }

    func testFailedSaveRollsBackBusinessAndJobThenRetryCoalesces() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        var measurement = BodyMeasurement(metric: .weightKg, value: 65)
        let job = HealthWriteJob(businessID: measurement.stamp.id, desiredRevision: 1, component: .weight, action: .write)
        await actor.injectCommitFailure()
        do { try await actor.save([.measurement(measurement)], jobs: [job]); XCTFail("Expected failure") } catch {}
        let rolledBack = try await actor.snapshot(), runtime = try await actor.runtimeSnapshot()
        XCTAssertEqual(rolledBack.count, 1); XCTAssertTrue(runtime.isEmpty)
        try await actor.save([.measurement(measurement)], jobs: [job])
        measurement.stamp.revision = 2; measurement.stamp.updatedAt = Date(); measurement.value = 66
        var latest = job; latest.desiredRevision = 2
        await actor.injectCommitFailure()
        do { try await actor.save([.measurement(measurement)], jobs: [latest]); XCTFail() } catch {}
        let originalJob = try await actor.runtimeSnapshot()
        XCTAssertEqual(originalJob, [.job(job)])
        let unchanged = try await actor.snapshot()
        XCTAssertTrue(unchanged.contains { if case .measurement(let v) = $0 { return v.value == 65 && v.stamp.revision == 1 }; return false })
        try await actor.save([.measurement(measurement)], jobs: [latest])
        let coalesced = try await actor.runtimeSnapshot()
        XCTAssertEqual(coalesced, [.job(latest)])
    }

    func testHealthBatchAndCursorRollbackAndRetryAreAtomic() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        let sample = ExternalNutritionSample(sampleUUID: UUID(), sourceBundleID: "example.other", occurred: RecordMoment(), component: .energy, value: 123)
        let cursor = HealthImportCursor(installationID: UUID(), sampleType: "energy", anchor: Data([1]), queryStart: DataFixtures.date)
        await actor.injectCommitFailure()
        do { try await actor.commitHealthImport([.nutrition(sample)], cursor: cursor); XCTFail() } catch {}
        let empty = try await actor.runtimeSnapshot(); XCTAssertTrue(empty.isEmpty)
        try await actor.commitHealthImport([.nutrition(sample)], cursor: cursor)
        try await actor.commitHealthImport([.nutrition(sample)], cursor: cursor)
        let runtime = try await actor.runtimeSnapshot(); XCTAssertEqual(runtime.count, 2)
        var next = cursor; next.anchor = Data([2])
        await actor.injectCommitFailure()
        do { try await actor.commitHealthImport([], deletedSampleIDs: [sample.sampleUUID], cursor: next); XCTFail() } catch {}
        let retained = try await actor.runtimeSnapshot(); XCTAssertEqual(retained, runtime)
        try await actor.commitHealthImport([], deletedSampleIDs: [sample.sampleUUID], cursor: next)
        let advanced = try await actor.runtimeSnapshot(); XCTAssertEqual(advanced, [.cursor(next)])
    }

    func testCatalogEditsDoNotMutateHistoricalSnapshots() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        let records = DataFixtures.records()
        try await actor.save(records)
        var changes: [BusinessRecord] = []
        for record in records {
            if case .exercise(var v) = record { v.name = "新动作名"; v.stamp.revision += 1; v.stamp.updatedAt = Date(); v.isArchived = true; changes.append(.exercise(v)) }
            if case .food(var v) = record { v.name = "新食物名"; v.nutrientsPer100Grams.energyKcal = 500; v.stamp.revision += 1; v.stamp.updatedAt = Date(); changes.append(.food(v)) }
            if case .template(var v) = record { v.items[0].plannedSets = 5; v.stamp.revision += 1; v.stamp.updatedAt = Date(); changes.append(.template(v)) }
        }
        try await actor.save(changes)
        let updated = try await actor.snapshot()
        for kind in ["session", "diet"] {
            XCTAssertEqual(updated.filter { $0.kind == kind }, records.filter { $0.kind == kind }.sorted { $0.id.uuidString < $1.id.uuidString })
        }
        if case .session(let v) = updated.first(where: { $0.kind == "session" }) {
            XCTAssertEqual(v.exercises[0].sets[0].effort?.scale, .rir)
        } else { XCTFail() }
        XCTAssertNil(Nutrients(energyKcal: 2).scaled(by: 3).proteinGrams)
    }

    func testRevisionAndSingleActiveWorkoutConstraints() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        let session = WorkoutSession(status: .active, name: "训练")
        try await actor.save([.session(session)])
        do { try await actor.save([.session(WorkoutSession(status: .paused, name: "另一个"))]); XCTFail() } catch {}
        var stale = session; stale.name = "未增加版本"
        do { try await actor.save([.session(stale)]); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let saved = try await actor.snapshot(); XCTAssertEqual(saved.filter { $0.kind == "session" }.count, 1)
    }

    func testTombstoneCancelsStaleWritesAndKeepsStableID() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        var item = BodyMeasurement(metric: .bodyFatPercent, value: 20)
        try await actor.save([.measurement(item)], jobs: [HealthWriteJob(businessID: item.stamp.id, desiredRevision: 1, component: .bodyFat, action: .write)])
        item.stamp.revision = 2; item.stamp.updatedAt = Date(); item.stamp.deletedAt = Date()
        let deletion = HealthWriteJob(businessID: item.stamp.id, desiredRevision: 2, component: .bodyFat, action: .delete)
        try await actor.save([.measurement(item)], jobs: [deletion])
        let state = try await actor.runtimeSnapshot(); XCTAssertEqual(state, [.job(deletion)])
        let saved = try await actor.snapshot(); XCTAssertTrue(saved.contains { $0.id == item.stamp.id && $0.stamp.deletedAt != nil })
    }

    func testUnknownNutrientDeletesOldComponentInsteadOfWritingZero() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        var entry = DietEntry(meal: .lunch, nutrients: Nutrients(energyKcal: 200, proteinGrams: 12))
        try await actor.save([.diet(entry)], jobs: [HealthWriteJob(businessID: entry.stamp.id, desiredRevision: 1, component: .protein, action: .write)])
        entry.nutrients.proteinGrams = nil; entry.stamp.revision = 2; entry.stamp.updatedAt = Date()
        let deletion = HealthWriteJob(businessID: entry.stamp.id, desiredRevision: 2, component: .protein, action: .delete)
        try await actor.save([.diet(entry)], jobs: [deletion])
        let jobs = try await actor.runtimeSnapshot(); XCTAssertEqual(jobs, [.job(deletion)])
        let records = try await actor.snapshot()
        XCTAssertTrue(records.contains { if case .diet(let v) = $0 { return v.nutrients.proteinGrams == nil }; return false })
    }

    func testGoalUpdatesKeepPastGoalsAndMultipleMeasurements() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.save(DataFixtures.records())
        try await actor.updatePreferences(weight: "lb", distance: "mi", days: 4, energy: 2300)
        let saved = try await actor.snapshot()
        XCTAssertEqual(saved.filter { $0.kind == "measurement" }.count, 2)
        XCTAssertTrue(saved.contains { if case .goal(let v) = $0 { return v.effectiveFrom == "2026-10-19" && v.nutrients.energyKcal == 2000 }; return false })
        XCTAssertTrue(saved.contains { if case .profile(let v) = $0 { return v.weightUnit == "lb" && v.weeklyTrainingDays == 4 }; return false })
    }

    func testDatabaseAndRecoveryAreExcludedFromBackupAndProtected() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await write(DataFixtures.records(), to: directory)
        let recovery = try StoreFactory.makeRecovery(in: directory)
        for url in [directory, directory.appendingPathComponent("Leanora.store"), recovery, recovery.appendingPathComponent("Leanora.store")] {
            XCTAssertEqual(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
            #if os(iOS) && !targetEnvironment(simulator)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
            #endif
        }
    }
}
