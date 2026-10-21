import XCTest
@testable import Leanora

@MainActor final class BackupTests: XCTestCase {
    func testRoundTripAdoptsIdentityPreservesSnapshotsAndIsIdempotent() async throws {
        let source = AppModelActor(modelContainer: try StoreFactory.memory())
        try await source.save(DataFixtures.records())
        let export = try await source.exportBackup()
        let target = AppModelActor(modelContainer: try StoreFactory.memory())
        try await target.initializeProfile()
        let preview = try await target.prepareImport(export.data)
        XCTAssertFalse(preview.differentIdentity)
        _ = try await target.importBackup(preview, acceptNewer: true)
        let restored = try await target.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(restored), export.fingerprint)
        let repeated = try await target.prepareImport(export.data)
        XCTAssertEqual(repeated.identical, DataFixtures.records().count)
        let outcome = try await target.importBackup(repeated, acceptNewer: true)
        XCTAssertEqual(outcome.inserted, 0); XCTAssertEqual(outcome.updated, 0)
        let runtime = try await target.runtimeSnapshot()
        XCTAssertTrue(runtime.contains(.reconciliationRequired(true))); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
        let item = BodyMeasurement(metric: .weightKg, value: 70)
        do {
            try await target.save([.measurement(item)], jobs: [HealthWriteJob(businessID: item.stamp.id, desiredRevision: 1, component: .weight, action: .write)])
            XCTFail()
        } catch { XCTAssertEqual(error as? DataProblem, .healthReconciliationRequired) }
    }

    func testExportExcludesHealthCachesJobsMappingsAndCursors() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        let item = BodyMeasurement(metric: .weightKg, value: 70)
        try await actor.save([.measurement(item)], jobs: [HealthWriteJob(businessID: item.stamp.id, desiredRevision: 1, component: .weight, action: .write)])
        let sampleID = UUID()
        try await actor.saveHealthMetadata(links: [HealthSampleLink(businessID: item.stamp.id, component: .weight, sampleUUID: sampleID,
                                                                   syncIdentifier: "private.sync.identifier", version: 1, sourceBundleID: "app.leanora.dev", state: .written)],
                                           suppressions: [HealthSuppression(sampleUUID: UUID(), businessID: nil, component: .weight, reason: "hidden")])
        let cursor = HealthImportCursor(installationID: UUID(), sampleType: "nutrition", anchor: Data([4, 5, 6]), queryStart: DataFixtures.date)
        try await actor.commitHealthImport([.nutrition(ExternalNutritionSample(sampleUUID: UUID(), sourceBundleID: "private.external.bundle", occurred: RecordMoment(), component: .protein, value: 12))], cursor: cursor)
        let export = try await actor.exportBackup()
        let string = String(decoding: export.data, as: UTF8.self)
        XCTAssertFalse(string.contains("private.external.bundle")); XCTAssertFalse(string.contains(cursor.installationID.uuidString))
        XCTAssertFalse(string.contains("private.sync.identifier")); XCTAssertFalse(string.contains(sampleID.uuidString))
        let decoded = try BackupService.decode(export.data)
        XCTAssertEqual(decoded.records.count, 2)
    }

    func testPreviewNewerOlderAndEqualRevisionConflictsPreservesCurrentByDefault() throws {
        let current = DataFixtures.records()
        var backup = current
        for index in backup.indices {
            if case .exercise(var v) = backup[index] { v.stamp.revision = 2; v.stamp.updatedAt = Date(); v.name = "较新动作"; backup[index] = .exercise(v) }
            if case .food(var v) = backup[index] { v.name = "同版本冲突"; backup[index] = .food(v) }
        }
        let preview = try BackupService.prepare(DataFixtures.encoded(backup), current: current)
        XCTAssertEqual(preview.newer, 1); XCTAssertEqual(preview.conflicts, 1)
        let (kept, result) = try BackupService.merge(preview, current: current, acceptNewer: false, replace: false, exportedFingerprint: nil)
        XCTAssertEqual(try RecordCoding.fingerprint(kept), try RecordCoding.fingerprint(current)); XCTAssertEqual(result.conflicts, 1)
        let (accepted, updated) = try BackupService.merge(preview, current: current, acceptNewer: true, replace: false, exportedFingerprint: nil)
        XCTAssertEqual(updated.updated, 1)
        let oldPreview = try BackupService.prepare(DataFixtures.encoded(current), current: accepted)
        XCTAssertEqual(oldPreview.older, 1)
        let (notDowngraded, _) = try BackupService.merge(oldPreview, current: accepted, acceptNewer: true, replace: false, exportedFingerprint: nil)
        XCTAssertEqual(try RecordCoding.fingerprint(notDowngraded), try RecordCoding.fingerprint(accepted))
    }

    func testDifferentIdentityRequiresCurrentExportAndExplicitReplacement() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        try await actor.save([.measurement(BodyMeasurement(metric: .weightKg, value: 80))])
        let backup = try DataFixtures.encoded(DataFixtures.records())
        let preview = try await actor.prepareImport(backup)
        XCTAssertTrue(preview.differentIdentity)
        do { _ = try await actor.importBackup(preview, acceptNewer: true); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .identityMismatch) }
        do { _ = try await actor.importBackup(preview, acceptNewer: true, replace: true); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .exportRequired) }
        let current = try await actor.exportBackup()
        _ = try await actor.importBackup(preview, acceptNewer: true, replace: true, exportedFingerprint: current.fingerprint)
        let restored = try await actor.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(restored), try RecordCoding.fingerprint(BackupService.decode(backup).records))
    }

    func testStalePreviewIsRejectedAfterLocalSave() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.save(DataFixtures.records())
        let preview = try await actor.prepareImport(DataFixtures.encoded(DataFixtures.records()))
        try await actor.save([.measurement(BodyMeasurement(metric: .weightKg, value: 50))])
        do { _ = try await actor.importBackup(preview, acceptNewer: true); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .stalePreview) }
        let saved = try await actor.snapshot(); XCTAssertEqual(saved.count, 12)
    }

    func testFailedImportLeavesEntireBusinessAndRuntimeUnchanged() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        let item = BodyMeasurement(metric: .weightKg, value: 70)
        try await actor.save([.measurement(item)], jobs: [HealthWriteJob(businessID: item.stamp.id, desiredRevision: 1, component: .weight, action: .write)])
        let original = try await actor.exportBackup(), runtime = try await actor.runtimeSnapshot()
        let preview = try await actor.prepareImport(DataFixtures.encoded(DataFixtures.records()))
        await actor.injectCommitFailure()
        do { _ = try await actor.importBackup(preview, acceptNewer: true, replace: true, exportedFingerprint: original.fingerprint); XCTFail() } catch {}
        let after = try await actor.exportBackup(), afterRuntime = try await actor.runtimeSnapshot()
        XCTAssertEqual(after.fingerprint, original.fingerprint); XCTAssertEqual(afterRuntime, runtime)
    }

    func testPreflightRejectsInvalidJSONUUIDReferencesRangesAndUnknownVersion() throws {
        let valid = try DataFixtures.encoded(DataFixtures.records())
        XCTAssertThrowsError(try BackupService.decode(Data("{bad".utf8)))
        var document = try BackupService.decode(valid); document.version = 999
        XCTAssertThrowsError(try BackupService.decode(RecordCoding.encode(document))) { XCTAssertEqual($0 as? DataProblem, .unsupportedVersion) }
        let invalidUUID = String(decoding: valid, as: UTF8.self).replacingOccurrences(of: DataFixtures.stamp(1).id.uuidString, with: "not-a-uuid")
        XCTAssertThrowsError(try BackupService.decode(Data(invalidUUID.utf8)))
        document = try BackupService.decode(valid)
        document.records.removeAll { $0.kind == "exercise" }
        XCTAssertThrowsError(try BackupService.decode(RecordCoding.encode(document)))
        document = try BackupService.decode(valid)
        document.records.append(.measurement(BodyMeasurement(metric: .bodyFatPercent, value: 101)))
        XCTAssertThrowsError(try BackupService.decode(RecordCoding.encode(document)))
        var moment = RecordMoment(); moment.localDate = "2020-99-99"
        XCTAssertThrowsError(try DomainValidation.moment(moment))
        XCTAssertThrowsError(try DomainValidation.validate([.profile(LocalProfile()), .food(Food(name: "饮品", nutrientsPer100Grams: Nutrients(energyKcal: 1), units: [FoodUnit(name: "毫升", grams: 1, milliliters: 1)]))]))
    }

    func testPreflightCountsNestedRecordsAndRejectsOversizedFileBeforeDecode() throws {
        let tooBig = Data(repeating: 0x20, count: BackupService.maximumBytes + 1)
        XCTAssertThrowsError(try BackupService.decode(tooBig)) { XCTAssertEqual($0 as? DataProblem, .tooLarge) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Leanora-size-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try tooBig.write(to: file)
        XCTAssertThrowsError(try BackupService.readFile(file)) { XCTAssertEqual($0 as? DataProblem, .tooLarge) }
        var exercise = Exercise(name: "动作")
        exercise.stamp = DataFixtures.stamp(2)
        let session = WorkoutSession(name: "训练", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: (0..<100_000).map { WorkoutSet(order: $0) })])
        XCTAssertThrowsError(try DomainValidation.validate([.profile(LocalProfile()), .exercise(exercise), .session(session)])) { XCTAssertEqual($0 as? DataProblem, .tooManyRecords) }
    }

    func testInvalidPreflightCannotChangeDatabase() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.save(DataFixtures.records())
        let before = try await actor.exportBackup()
        do { _ = try await actor.prepareImport(Data("{}".utf8)); XCTFail() } catch {}
        let after = try await actor.exportBackup(); XCTAssertEqual(after.fingerprint, before.fingerprint)
    }
}
