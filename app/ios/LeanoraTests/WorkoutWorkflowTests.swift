import XCTest
@testable import Leanora

final class WorkoutWorkflowTests: XCTestCase, @unchecked Sendable {
    private func actor() async throws -> AppModelActor {
        let value = AppModelActor(modelContainer: try StoreFactory.memory())
        try await value.initializeProfile()
        return value
    }
    private func history(_ exercise: Exercise, end: Date = Date().addingTimeInterval(-60)) -> WorkoutSession {
        let sets = [WorkoutSet(order: 0, kind: .warmup, loadKg: 10, repetitions: 10, completedAt: end.addingTimeInterval(-20)),
                    WorkoutSet(order: 1, loadKg: 20, repetitions: 8, effort: EffortValue(scale: .rpe, value: 7), completedAt: end.addingTimeInterval(-10)),
                    WorkoutSet(order: 2, loadKg: 25, repetitions: 6, completedAt: end)]
        return WorkoutSession(started: RecordMoment(end.addingTimeInterval(-90)), endedAt: end, status: .completed,
                              name: "上次训练", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: sets)])
    }
    func testFreeStartIsIdempotentAndDoesNotCreateTemplateOrHealthJob() async throws {
        let store = try await actor()
        try await store.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.workout]))
        let first = try await store.startFreeTraining(), second = try await store.startFreeTraining()
        XCTAssertEqual(first.stamp.id, second.stamp.id); XCTAssertTrue(first.exercises.isEmpty)
        let records = try await store.snapshot(), runtime = try await store.runtimeSnapshot()
        XCTAssertFalse(records.contains { $0.kind == "template" }); XCTAssertTrue(runtime.allSatisfy { if case .job = $0 { return false }; return true })
        do { _ = try await store.finishWorkout(first.stamp.id); XCTFail() } catch {}
    }
    func testAddingCatalogExercisePersistsDependencyAndPrefillsOnlyNewItem() async throws {
        let store = try await actor(), exercise = Exercise(name: "目录动作")
        let prior = history(exercise)
        try await store.save([.exercise(exercise), .session(prior)])
        let session = try await store.startFreeTraining()
        try await store.addExerciseToWorkout(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.stamp.id, catalog: [exercise])
        var saved = try await store.workout(session.stamp.id)
        XCTAssertEqual(saved.exercises[0].sets[0].loadKg, 20)
        XCTAssertTrue(saved.exercises[0].sets.allSatisfy { $0.completedAt == nil && $0.effort == nil })
        saved.exercises[0].sets[0].loadKg = 99; try await store.saveWorkout(saved)
        saved = try await store.workout(session.stamp.id)
        let other = Exercise(name: "新目录动作", measurement: .bodyweight)
        try await store.addExerciseToWorkout(saved.stamp.id, revision: saved.stamp.revision, exerciseID: other.stamp.id, catalog: [other])
        let result = try await store.workout(saved.stamp.id), records = try await store.snapshot()
        XCTAssertEqual(result.exercises[0].sets[0].loadKg, 99); XCTAssertEqual(result.exercises.count, 2)
        XCTAssertTrue(records.contains { $0.id == other.stamp.id })
        do { try await store.addExerciseToWorkout(saved.stamp.id, revision: saved.stamp.revision, exerciseID: other.stamp.id, catalog: [other]); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
    }
    func testAddingExerciseFailureRollsBackDependencyAndSessionTogether() async throws {
        let store = try await actor(), exercise = Exercise(name: "回滚动作")
        let session = try await store.startFreeTraining()
        let before = try await store.workout(session.stamp.id)
        await store.injectCommitFailure()
        do { try await store.addExerciseToWorkout(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.stamp.id, catalog: [exercise]); XCTFail() } catch {}
        let saved = try await store.workout(session.stamp.id), records = try await store.snapshot()
        XCTAssertEqual(saved, before); XCTAssertFalse(records.contains { $0.id == exercise.stamp.id })
    }
    func testArchivedExerciseAndCompletedSessionRejectAdditions() async throws {
        let store = try await actor(), exercise = Exercise(name: "归档动作", isArchived: true)
        let session = try await store.startFreeTraining()
        do { try await store.addExerciseToWorkout(session.stamp.id, revision: 1, exerciseID: exercise.stamp.id, catalog: [exercise]); XCTFail() }
        catch { XCTAssertEqual(error as? TrainingProblem, .archivedExercise) }
        try await store.abandonTraining(session.stamp.id)
        let saved = try await store.workout(session.stamp.id)
        do { try await store.addExerciseToWorkout(saved.stamp.id, revision: saved.stamp.revision, exerciseID: exercise.stamp.id, catalog: [exercise]); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
    }
    func testReferenceIgnoresCurrentFutureDeletedIncompleteAndChangedMeasurement() {
        let exercise = Exercise(name: "卧推"), now = Date()
        var current = WorkoutSession(started: RecordMoment(now), status: .active, name: "当前", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0)])])
        let good = history(exercise)
        var future = history(exercise, end: now.addingTimeInterval(60)), deleted = history(exercise, end: now.addingTimeInterval(-1))
        deleted.stamp.deletedAt = Date()
        var incomplete = history(exercise, end: now.addingTimeInterval(-2)); incomplete.status = .abandoned
        var wrong = history(exercise, end: now.addingTimeInterval(-3)); wrong.exercises[0].snapshot.measurement = .assistedLoad
        future.exercises[0].sets[1].loadKg = 1000
        let result = WorkoutReuse.reference(for: current.exercises[0], in: current, history: [future, wrong, deleted, incomplete, good])
        XCTAssertEqual(result?.sessionID, good.stamp.id)
        current.status = .completed; current.endedAt = now.addingTimeInterval(-1)
        XCTAssertNil(WorkoutReuse.reference(for: current.exercises[0], in: current, history: [current]))
    }
    func testReuseMatchesSetKindAndDoesNotOverwriteCompletedOrCopyEffort() {
        let exercise = Exercise(name: "卧推"), source = history(Exercise(name: "unused"))
        var prior = source; prior.exercises[0].snapshot = ExerciseSnapshot(exercise)
        var current = WorkoutSession(status: .active, name: "当前", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0), WorkoutSet(order: 1)])])
        let reference = WorkoutReuse.reference(for: current.exercises[0], in: current, history: [prior])!
        var result = WorkoutReuse.applying(reference, to: current.exercises[0])
        XCTAssertEqual(result.sets[0].loadKg, 20); XCTAssertEqual(result.sets[1].loadKg, 25)
        XCTAssertTrue(result.sets.allSatisfy { $0.effort == nil && $0.completedAt == nil })
        current.exercises[0].sets[0].completedAt = Date(); current.exercises[0].sets[0].loadKg = 99
        result = WorkoutReuse.applying(reference, to: current.exercises[0])
        XCTAssertEqual(result.sets[0].loadKg, 99); XCTAssertNotNil(result.sets[0].completedAt)
    }
    func testReuseDoesNotResetMeasuredOrRunningTimer() {
        let exercise = Exercise(name: "平板", measurement: .duration), now = Date()
        let previous = SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, durationSeconds: 60, completedAt: now)])
        let current = SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, durationSeconds: 12, timerStartedAt: now, accumulatedSeconds: 12), WorkoutSet(order: 1, durationSeconds: 20, accumulatedSeconds: 20)])
        let result = WorkoutReuse.applying(WorkoutReference(sessionID: UUID(), date: "2026-10-28", exercise: previous), to: current)
        XCTAssertEqual(result, current)
    }
    func testRepeatCreatesNewIDsPreservesKindsAndLeavesSourceAndHealthQueueUnchanged() async throws {
        let store = try await actor(), exercise = Exercise(name: "再练动作"), prior = history(Exercise(name: "placeholder"))
        var source = prior; source.exercises[0].snapshot = ExerciseSnapshot(exercise)
        source.exercises[0].sets.append(WorkoutSet(order: 3))
        try await store.save([.exercise(exercise), .session(source)])
        let before = try await store.workout(source.stamp.id)
        try await store.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.workout]))
        let fresh = try await store.repeatWorkout(source.stamp.id, catalog: [])
        let repeatTap = try await store.repeatWorkout(source.stamp.id, catalog: [])
        XCTAssertEqual(fresh.stamp.id, repeatTap.stamp.id); XCTAssertNil(fresh.templateID); XCTAssertNil(fresh.scheduleOriginDate)
        XCTAssertEqual(fresh.exercises[0].sets.count, 3); XCTAssertEqual(fresh.exercises[0].sets[0].kind, .warmup)
        XCTAssertTrue(Set(BusinessRecord.session(fresh).nestedIDs).isDisjoint(with: BusinessRecord.session(source).nestedIDs))
        XCTAssertTrue(fresh.exercises.flatMap(\.sets).allSatisfy { $0.completedAt == nil && $0.timerStartedAt == nil && $0.effort == nil && $0.accumulatedSeconds == 0 })
        let original = try await store.workout(source.stamp.id), runtime = try await store.runtimeSnapshot()
        XCTAssertEqual(original, before); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
        var active = fresh
        try WorkoutEngine.complete(&active, exercise: 0, set: 1, at: Date()); try await store.saveWorkout(active)
        _ = try await store.finishWorkout(active.stamp.id)
        let jobs = try await store.runtimeSnapshot()
        XCTAssertEqual(jobs.filter { if case .job(let job) = $0 { return job.businessID == active.stamp.id }; return false }.count, 1)
    }
    func testRemovingSupersetMemberUnpairsPartnerAndClearsRemovedTimerIDs() {
        let exercise = Exercise(name: "配对"), group = UUID()
        let first = SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0)], supersetID: group)
        let second = SessionExercise(order: 1, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0)], supersetID: group)
        var session = WorkoutSession(status: .paused, name: "配对", exercises: [first, second], restDeadline: Date(), pausedTimerSetIDs: [first.sets[0].id])
        XCTAssertNoThrow(try WorkoutReuse.removeExercise(first.id, from: &session))
        XCTAssertEqual(session.exercises.count, 1); XCTAssertEqual(session.exercises[0].order, 0)
        XCTAssertNil(session.exercises[0].supersetID); XCTAssertNil(session.restDeadline); XCTAssertEqual(session.pausedTimerSetIDs, [])
    }
    func testTemplateProjectionUsesCompletedWorkingSetsAndPreservesOriginalSchedule() throws {
        let exercise = Exercise(name: "动作"), original = WorkoutTemplate(name: "原模板", scheduledWeekdays: [1,3], notes: "原备注")
        var source = history(exercise); source.templateID = original.stamp.id; source.templateRevision = original.stamp.revision
        let fresh = try WorkoutReuse.template(from: source, exercises: [exercise])
        XCTAssertEqual(fresh.items[0].plannedSets, 2); XCTAssertEqual(fresh.items[0].loadKg, 20); XCTAssertEqual(fresh.items[0].minimumReps, 8)
        XCTAssertNotEqual(fresh.stamp.id, original.stamp.id)
        let updated = try WorkoutReuse.template(from: source, exercises: [exercise], original: original)
        XCTAssertEqual(updated.stamp, original.stamp); XCTAssertEqual(updated.name, original.name)
        XCTAssertEqual(updated.scheduledWeekdays, [1,3]); XCTAssertEqual(updated.notes, "原备注")
        var changed = original; changed.stamp.revision += 1
        XCTAssertThrowsError(try WorkoutReuse.template(from: source, exercises: [exercise], original: changed))
        source.exercises[0].sets = [source.exercises[0].sets[0]]
        XCTAssertThrowsError(try WorkoutReuse.template(from: source, exercises: [exercise]))
    }
    func testFavoriteSurvivesLegacyDecodeDiskReopenAndBackupRestore() async throws {
        let directory = DataFixtures.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let exercise = Exercise(name: "收藏动作")
        let data = try RecordCoding.encode(exercise)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("isFavorite"))
        XCTAssertNil(try RecordCoding.decode(Exercise.self, from: data).isFavorite)
        do {
            let store = AppModelActor(modelContainer: try StoreFactory.open(directory: directory)); try await store.initializeProfile()
            try await store.setExerciseFavorite(exercise.stamp.id, favorite: true, catalog: [exercise])
        }
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let values = try await reopened.trainingExercises(catalog: [exercise])
        XCTAssertEqual(values[0].isFavorite, true)
        let backup = try await reopened.exportBackup(), restored = try await actor()
        let preview = try await restored.prepareImport(backup.data)
        _ = try await restored.importBackup(preview, acceptNewer: false)
        let imported = try await restored.trainingExercises(catalog: [exercise])
        XCTAssertEqual(imported[0].isFavorite, true)
        try await restored.setExerciseFavorite(exercise.stamp.id, favorite: false, catalog: [exercise])
        let unstarred = try await restored.trainingExercises(catalog: [exercise]); XCTAssertNil(unstarred[0].isFavorite)
    }
    func testRecentExercisesIgnoreUnfinishedAbandonedAndDeletedAndKeepOrder() {
        let a = Exercise(name: "A"), b = Exercise(name: "B"), c = Exercise(name: "C"), now = Date()
        var recent = history(b, end: now), abandoned = history(c, end: now.addingTimeInterval(5)), deleted = history(c, end: now.addingTimeInterval(10))
        recent.exercises.append(SessionExercise(order: 1, snapshot: ExerciseSnapshot(c), sets: [WorkoutSet(order: 0)]))
        abandoned.status = .abandoned; deleted.stamp.deletedAt = now
        let values = [history(a, end: now.addingTimeInterval(-10)), recent, abandoned, deleted]
        XCTAssertEqual(WorkoutReuse.recentExerciseIDs(in: values), [b.stamp.id,a.stamp.id])
        XCTAssertEqual(WorkoutReuse.recentExerciseIDs(in: values, limit: 1), [b.stamp.id])
    }

    func testTemplateDraftDoesNotWriteAndStaleOriginalCannotOverwriteNewerEdits() async throws {
        let store = try await actor(), exercise = Exercise(name: "模板更新动作")
        let original = WorkoutTemplate(name: "原模板", items: [TrainingPlan.newItem(for: exercise, order: 0)], scheduledWeekdays: [2,4])
        var source = history(exercise)
        source.templateID = original.stamp.id; source.templateRevision = original.stamp.revision
        try await store.save([.exercise(exercise), .template(original), .session(source)])
        let before = try await store.snapshot()
        let draft = try await store.templateFromWorkout(source.stamp.id, updateOriginal: true, catalog: [])
        let afterPreview = try await store.snapshot()
        XCTAssertEqual(afterPreview, before)
        XCTAssertEqual(draft.items[0].plannedSets, 2)
        var renamed = original; renamed.name = "较新的模板名称"
        let newer = try await store.saveTrainingTemplate(renamed, catalog: [])
        do { _ = try await store.saveTrainingTemplate(draft, catalog: []); XCTFail("Stale draft overwrote newer template") }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        do { _ = try await store.templateFromWorkout(source.stamp.id, updateOriginal: true, catalog: []); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let records = try await store.snapshot()
        guard case .template(let saved) = records.first(where: { $0.id == original.stamp.id }) else { return XCTFail() }
        XCTAssertEqual(saved.name, newer.name); XCTAssertEqual(saved.scheduledWeekdays, [2,4])
        let newDraft = try await store.templateFromWorkout(source.stamp.id, updateOriginal: false, catalog: [])
        XCTAssertNotEqual(newDraft.stamp.id, original.stamp.id)
    }

    func testFreeWorkoutRecoversAfterDiskReopenAndFavoriteFailureRollsBack() async throws {
        let directory = DataFixtures.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let exercise = Exercise(name: "自由训练恢复", measurement: .bodyweight)
        var saved: WorkoutSession!
        do {
            let store = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
            try await store.initializeProfile()
            let active = try await store.startFreeTraining()
            try await store.addExerciseToWorkout(active.stamp.id, revision: active.stamp.revision, exerciseID: exercise.stamp.id, catalog: [exercise])
            var edited = try await store.workout(active.stamp.id); edited.exercises[0].sets[0].repetitions = 12
            try await store.saveWorkout(edited)
            saved = try await store.workout(active.stamp.id)
        }
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let recovered = try await reopened.startFreeTraining()
        XCTAssertEqual(recovered, saved)
        await reopened.injectCommitFailure()
        do { try await reopened.setExerciseFavorite(exercise.stamp.id, favorite: true, catalog: [exercise]); XCTFail() } catch {}
        let exercises = try await reopened.trainingExercises(catalog: [exercise])
        XCTAssertNil(exercises.first(where: { $0.stamp.id == exercise.stamp.id })?.isFavorite)
        let workout = try await reopened.workout(saved.stamp.id)
        XCTAssertEqual(workout, saved)
    }
}
