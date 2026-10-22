import XCTest
import SwiftData
@testable import Leanora

@MainActor final class TrainingPlanTests: XCTestCase {
    private func actor() async throws -> AppModelActor {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile(); return actor
    }
    private func template(_ catalog: [Exercise], weekdays: [Int] = []) -> WorkoutTemplate {
        WorkoutTemplate(name: "力量日", items: [TrainingPlan.newItem(for: catalog[0], order: 0)], scheduledWeekdays: weekdays)
    }
    private func time(_ date: String) -> Date {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Shanghai"); f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date + " 10:00")!
    }

    func testBundledCatalogHasStableSourcesAndCombinedSearchFilters() throws {
        let catalog = try ExerciseCatalog.load()
        XCTAssertEqual(catalog.count, 882); XCTAssertEqual(Set(catalog.map { $0.stamp.id }).count, 882)
        XCTAssertTrue(catalog.prefix(100).allSatisfy { $0.source.reference == "leanora:catalog/exercises/v1" && $0.source.license == "项目自有内容" })
        XCTAssertTrue(catalog.dropFirst(100).allSatisfy { $0.source.license == "Unlicense" })
        XCTAssertEqual(ExerciseSearch.filter(catalog, query: "BENCH", muscle: "上肢", equipment: "哑铃").map(\.name), ["哑铃卧推"])
        XCTAssertTrue(ExerciseSearch.filter(catalog, query: "不存在", muscle: nil, equipment: nil).isEmpty)
        var archived = catalog[0]; archived.isArchived = true
        XCTAssertTrue(ExerciseSearch.filter([archived], query: "", muscle: nil, equipment: nil).isEmpty)
        XCTAssertEqual(ExerciseSearch.filter([archived], query: "", muscle: nil, equipment: nil, archived: true).count, 1)
    }

    func testTemplatePersistsOnlyUsedCatalogDependenciesAtomically() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let draft = template(catalog)
        await actor.injectCommitFailure()
        do { _ = try await actor.saveTrainingTemplate(draft, catalog: catalog); XCTFail() } catch {}
        let rolledBack = try await actor.snapshot(); XCTAssertEqual(rolledBack.count, 1)
        let saved = try await actor.saveTrainingTemplate(draft, catalog: catalog)
        XCTAssertEqual(saved.stamp.id, draft.stamp.id)
        let records = try await actor.snapshot(); XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records.filter { $0.kind == "exercise" }.count, 1)
    }

    func testCopyHasNewParentAndItemIDsAndNoWeeklySchedule() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let original = try await actor.saveTrainingTemplate(template(catalog, weekdays: [1, 3]), catalog: catalog)
        let copy = try await actor.copyTrainingTemplate(original.stamp.id)
        XCTAssertNotEqual(copy.stamp.id, original.stamp.id); XCTAssertNotEqual(copy.items[0].id, original.items[0].id)
        XCTAssertEqual(copy.items[0].exerciseID, original.items[0].exerciseID)
        XCTAssertTrue(copy.scheduledWeekdays.isEmpty); XCTAssertTrue(copy.name.contains("副本"))
    }

    func testDuplicateExerciseItemsReorderAndKeepIndependentTargets() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        var draft = template(catalog)
        var second = TrainingPlan.newItem(for: catalog[0], order: 1); second.plannedSets = 5; second.loadKg = 40
        draft.items.append(second)
        let first = try await actor.saveTrainingTemplate(draft, catalog: catalog)
        var reordered = first; reordered.items.swapAt(0, 1)
        let saved = try await actor.saveTrainingTemplate(reordered, catalog: catalog)
        XCTAssertEqual(saved.items.map(\.order), [0, 1]); XCTAssertEqual(saved.items[0].id, second.id)
        let session = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog)
        XCTAssertEqual(session.exercises.map { $0.plannedTargets?.sets }, [5, 3])
        XCTAssertEqual(Set(session.exercises.map(\.id)).count, 2)
        XCTAssertEqual(session.exercises[0].templateItemID, second.id)
        XCTAssertTrue(session.exercises.flatMap(\.sets).allSatisfy { $0.completedAt == nil && $0.loadKg == nil && $0.repetitions == nil })
    }

    func testEmptyTemplateCannotStart() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(WorkoutTemplate(name: "空模板"), catalog: catalog)
        do { _ = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog); XCTFail() }
        catch { XCTAssertEqual(error as? TrainingProblem, .emptyTemplate) }
        let records = try await actor.snapshot(); XCTAssertFalse(records.contains { $0.kind == "session" })
    }

    func testConcurrentStartReturnsSameActiveSession() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(template(catalog), catalog: catalog)
        async let a = actor.startTraining(templateID: saved.stamp.id, catalog: catalog)
        async let b = actor.startTraining(templateID: saved.stamp.id, catalog: catalog)
        let (first, second) = try await (a, b)
        XCTAssertEqual(first.stamp.id, second.stamp.id)
        let records = try await actor.snapshot(); XCTAssertEqual(records.filter { $0.kind == "session" }.count, 1)
    }

    func testTemplateAndCustomExerciseChangesLeaveStartedSnapshotUntouched() async throws {
        let actor = try await actor()
        let exercise = Exercise(name: "自定义推举", equipment: "哑铃")
        try await actor.saveCustomExercise(exercise, catalog: [])
        var draft = WorkoutTemplate(name: "自定义日", items: [TrainingPlan.newItem(for: exercise, order: 0)])
        draft.items[0].loadKg = 20
        let saved = try await actor.saveTrainingTemplate(draft, catalog: [])
        let started = try await actor.startTraining(templateID: saved.stamp.id, catalog: [])
        var changed = saved; changed.items[0].plannedSets = 8; changed.name = "新模板名"
        _ = try await actor.saveTrainingTemplate(changed, catalog: [])
        var renamed = exercise; renamed.name = "新的动作名"
        try await actor.saveCustomExercise(renamed, catalog: [])
        try await actor.setExerciseArchived(exercise.stamp.id, archived: true, catalog: [])
        let records = try await actor.snapshot()
        let retained = try XCTUnwrap(records.compactMap { if case .session(let v) = $0 { return v }; return nil }.first)
        XCTAssertEqual(try RecordCoding.encode(retained), try RecordCoding.encode(started))
        try await actor.abandonTraining(started.stamp.id)
        do { _ = try await actor.startTraining(templateID: saved.stamp.id, catalog: []); XCTFail() }
        catch { XCTAssertEqual(error as? TrainingProblem, .archivedExercise) }
        try await actor.setExerciseArchived(exercise.stamp.id, archived: false, catalog: [])
        let resumed = try await actor.startTraining(templateID: saved.stamp.id, catalog: [])
        XCTAssertNotEqual(resumed.stamp.id, started.stamp.id); XCTAssertEqual(resumed.exercises[0].snapshot.name, "新的动作名")
    }

    func testOneOffMoveLeavesWeeklyTemplateAndFollowingWeekUnchanged() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(template(catalog, weekdays: [1]), catalog: catalog)
        try await actor.rescheduleTraining(templateID: saved.stamp.id, originDate: "2026-10-19", destinationDate: "2026-10-20", timeZoneID: "Asia/Shanghai")
        var records = try await actor.snapshot()
        let changes = records.compactMap { if case .schedule(let v) = $0 { return v }; return nil }
        XCTAssertEqual(TrainingPlan.occurrences(on: "2026-10-19", templates: [saved], changes: changes).count, 0)
        XCTAssertEqual(TrainingPlan.occurrences(on: "2026-10-20", templates: [saved], changes: changes).first?.originDate, "2026-10-19")
        XCTAssertEqual(TrainingPlan.occurrences(on: "2026-10-26", templates: [saved], changes: changes).count, 1)
        let retained = try XCTUnwrap(records.first { $0.id == saved.stamp.id })
        XCTAssertEqual(try RecordCoding.encode(retained), try RecordCoding.encode(BusinessRecord.template(saved)))
        try await actor.rescheduleTraining(templateID: saved.stamp.id, originDate: "2026-10-19", destinationDate: "2026-10-19", timeZoneID: "Asia/Shanghai")
        records = try await actor.snapshot()
        let movedBack = records.compactMap { if case .schedule(let v) = $0 { return v }; return nil }
        XCTAssertEqual(movedBack.count, 1)
        XCTAssertEqual(TrainingPlan.occurrences(on: "2026-10-19", templates: [saved], changes: movedBack).count, 1)
    }

    func testMovedOccurrenceStartsOnDestinationAndCannotMoveAfterStart() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(template(catalog, weekdays: [1]), catalog: catalog)
        try await actor.rescheduleTraining(templateID: saved.stamp.id, originDate: "2026-10-19", destinationDate: "2026-10-20", timeZoneID: "Asia/Shanghai")
        do { _ = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog, originDate: "2026-10-19", now: time("2026-10-19"), timeZoneID: "Asia/Shanghai"); XCTFail() } catch {}
        let session = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog, originDate: "2026-10-19", now: time("2026-10-20"), timeZoneID: "Asia/Shanghai")
        XCTAssertEqual(session.started.localDate, "2026-10-20"); XCTAssertEqual(session.scheduleOriginDate, "2026-10-19")
        do { try await actor.rescheduleTraining(templateID: saved.stamp.id, originDate: "2026-10-19", destinationDate: "2026-10-21", timeZoneID: "Asia/Shanghai"); XCTFail() }
        catch { XCTAssertEqual(error as? TrainingProblem, .startedOccurrence) }
    }

    func testPlanAndSessionRoundTripDiskAndBackup() async throws {
        let directory = DataFixtures.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try ExerciseCatalog.load()
        let original = try await persistPlan(directory, catalog: catalog)
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let export = try await reopened.exportBackup()
        let restored = try await actor()
        let preview = try await restored.prepareImport(export.data)
        _ = try await restored.importBackup(preview, acceptNewer: true)
        let records = try await restored.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(records), original)
        XCTAssertTrue(records.contains { $0.kind == "schedule" })
        let runtime = try await restored.runtimeSnapshot(); XCTAssertTrue(runtime.contains(.reconciliationRequired(true))); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
    }
    private func persistPlan(_ directory: URL, catalog: [Exercise]) async throws -> String {
        let actor = AppModelActor(modelContainer: try StoreFactory.open(directory: directory)); try await actor.initializeProfile()
        let saved = try await actor.saveTrainingTemplate(template(catalog, weekdays: [1]), catalog: catalog)
        try await actor.rescheduleTraining(templateID: saved.stamp.id, originDate: "2026-10-19", destinationDate: "2026-10-20", timeZoneID: "Asia/Shanghai")
        _ = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog, originDate: "2026-10-19", now: time("2026-10-20"), timeZoneID: "Asia/Shanghai")
        return try await actor.exportBackup().fingerprint
    }

    func testStaleTemplateEditDoesNotOverwriteNewerRevision() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(template(catalog), catalog: catalog)
        var first = saved; first.name = "最新"
        _ = try await actor.saveTrainingTemplate(first, catalog: catalog)
        do { _ = try await actor.saveTrainingTemplate(saved, catalog: catalog); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
    }

    func testTargetInputUsesCanonicalUnitsAndRejectsInvalidValues() throws {
        let exercise = Exercise(name: "力量")
        let item = TrainingPlan.newItem(for: exercise, order: 0)
        let input = TrainingTargetInput(minimum: "8", maximum: "12", load: "10,5", rest: "90")
        let saved = try input.applying(to: item, measurement: .externalLoad, pounds: true, miles: false)
        XCTAssertEqual(try XCTUnwrap(saved.loadKg), 10.5 * 0.45359237, accuracy: 0.000001)
        let cardio = try TrainingTargetInput(duration: "600", distance: "2", rest: "0").applying(to: item, measurement: .cardio, pounds: false, miles: true)
        XCTAssertEqual(cardio.distanceMeters, 3218.688)
        for text in ["-1", "1e5", "nan", "１", "1.2.3"] { XCTAssertThrowsError(try TrainingTargetInput.decimal(text)) }
        XCTAssertThrowsError(try TrainingTargetInput(minimum: "13", maximum: "8").applying(to: item, measurement: .bodyweight, pounds: false, miles: false))
        XCTAssertNil(try TrainingTargetInput(rest: "0").applying(to: item, measurement: .duration, pounds: false, miles: false).loadKg)
    }

    func testOversizedExpandedPlanIsRejectedBeforeAllocatingSets() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let items = (0..<100).map { index in
            var item = TrainingPlan.newItem(for: catalog[0], order: index); item.plannedSets = 1000; return item
        }
        let saved = try await actor.saveTrainingTemplate(WorkoutTemplate(name: "大量计划组", items: items), catalog: catalog)
        do { _ = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .tooManyRecords) }
        let records = try await actor.snapshot(); XCTAssertFalse(records.contains { $0.kind == "session" })
    }

    func testDeletingUsedTemplateKeepsStartedSnapshotAndRemovesRecurrence() async throws {
        let actor = try await actor(), catalog = try ExerciseCatalog.load()
        let saved = try await actor.saveTrainingTemplate(template(catalog, weekdays: [1]), catalog: catalog)
        let started = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog)
        try await actor.deleteTrainingTemplate(saved)
        let records = try await actor.snapshot()
        let templates = records.compactMap { if case .template(let v) = $0 { return v }; return nil }
        XCTAssertTrue(TrainingPlan.occurrences(on: "2026-10-19", templates: templates, changes: []).isEmpty)
        XCTAssertEqual(try RecordCoding.encode(XCTUnwrap(records.first { $0.id == started.stamp.id })), try RecordCoding.encode(BusinessRecord.session(started)))
        do { _ = try await actor.copyTrainingTemplate(saved.stamp.id); XCTFail() } catch { XCTAssertEqual(error as? TrainingProblem, .missingRecord) }
    }

    func testImportedFutureActiveWorkoutCanBeAbandonedAfterClockChange() async throws {
        let actor = try await actor()
        let future = Date().addingTimeInterval(86400)
        let session = WorkoutSession(started: RecordMoment(future), status: .active, name: "未来时刻记录")
        try await actor.save([.session(session)])
        try await actor.abandonTraining(session.stamp.id)
        let records = try await actor.snapshot()
        let ended = try XCTUnwrap(records.compactMap { if case .session(let v) = $0 { return v }; return nil }.first)
        XCTAssertEqual(ended.status, .abandoned)
        XCTAssertEqual(ended.started.instant.timeIntervalSince1970, future.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(ended.endedAt), ended.started.instant)
    }
}
