import XCTest
@testable import Leanora

final class WorkoutRecordingTests: XCTestCase, @unchecked Sendable {
    private func fixture(_ measurement: ExerciseMeasurement = .externalLoad) async throws -> (AppModelActor, WorkoutSession, Exercise) {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        let exercise = Exercise(name: "测试卧推", measurement: measurement)
        var session = try await actor.startFreeTraining()
        try await actor.addExerciseToWorkout(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.stamp.id, catalog: [exercise])
        session = try await actor.workout(session.stamp.id)
        return (actor, session, exercise)
    }
    private func input(_ load: String = "20", _ reps: String = "8") -> WorkoutSetInput {
        var value = WorkoutSetInput(); value.load = load; value.repetitions = reps; return value
    }
    func testInputAndCompletionCommitTogetherAndRetryIsIdempotent() async throws {
        let (actor, session, _) = try await fixture()
        let exercise = session.exercises[0], set = exercise.sets[0], now = Date()
        try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: set.id, input: input(), pounds: false, miles: false, now: now)
        let saved = try await actor.workout(session.stamp.id)
        XCTAssertEqual(saved.exercises[0].sets[0].loadKg, 20)
        XCTAssertEqual(saved.exercises[0].sets[0].completedAt!.timeIntervalSince(now), 0, accuracy: 0.001)
        try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: set.id, input: input("99", "1"), pounds: false, miles: false)
        let replayed = try await actor.workout(session.stamp.id)
        XCTAssertEqual(replayed, saved)
    }
    func testFailedCommitKeepsActualAndCompletionUnchangedThenRetrySucceeds() async throws {
        let (actor, session, _) = try await fixture(); let exercise = session.exercises[0]
        await actor.injectCommitFailure()
        do {
            try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: input(), pounds: false, miles: false)
            XCTFail("Expected failure")
        } catch {}
        let unchanged = try await actor.workout(session.stamp.id); XCTAssertEqual(unchanged, session)
        try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: input(), pounds: false, miles: false)
        let saved = try await actor.workout(session.stamp.id); XCTAssertNotNil(saved.exercises[0].sets[0].completedAt)
    }
    func testInvalidInputOrStaleRevisionCannotPartiallyComplete() async throws {
        let (actor, session, _) = try await fixture(); let exercise = session.exercises[0]
        for value in [input("NaN"), input("20", "0"), input("20", "1.5"), input("6000")] {
            do { try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: value, pounds: false, miles: false); XCTFail() } catch {}
        }
        var newer = session; newer.notes = "新版本"; try await actor.saveWorkout(newer)
        do { try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: input(), pounds: false, miles: false); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let saved = try await actor.workout(session.stamp.id)
        XCTAssertEqual(saved.notes, "新版本"); XCTAssertNil(saved.exercises[0].sets[0].loadKg)
    }
    func testPauseRestSurvivesCodingAndResumePreservesRemainingTime() throws {
        let now = Date(); var session = WorkoutSession(status: .active, name: "休息", restDeadline: now.addingTimeInterval(80))
        try WorkoutEngine.pause(&session, at: now)
        XCTAssertNil(session.restDeadline); XCTAssertEqual(session.pausedRestRemainingSeconds, 80)
        session = try RecordCoding.decode(WorkoutSession.self, from: RecordCoding.encode(session))
        try WorkoutEngine.resume(&session, at: now.addingTimeInterval(600))
        XCTAssertEqual(session.restDeadline, now.addingTimeInterval(680)); XCTAssertNil(session.pausedRestRemainingSeconds)
    }
    func testOldPausedPayloadRecoversDeadlineAtPauseInstant() throws {
        let now = Date(); var session = WorkoutSession(status: .paused, name: "旧版", pauses: [PauseInterval(startedAt: now)], restDeadline: now.addingTimeInterval(30))
        let encoded = try RecordCoding.encode(session)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("pausedRestRemainingSeconds"))
        session = try RecordCoding.decode(WorkoutSession.self, from: encoded)
        XCTAssertEqual(WorkoutEngine.pausedRestRemaining(in: session), 30)
        try WorkoutEngine.resume(&session, at: now.addingTimeInterval(500))
        XCTAssertEqual(session.restDeadline, now.addingTimeInterval(530))
    }
    @MainActor func testPausedSessionSchedulesNeitherRestNorActionNotifications() throws {
        let now = Date(); var session = WorkoutSession(status: .active, name: "休息", restDeadline: now.addingTimeInterval(30))
        XCTAssertEqual(WorkoutNotificationService.reminders(for: session, at: now).count, 1)
        try WorkoutEngine.pause(&session, at: now)
        XCTAssertTrue(WorkoutNotificationService.reminders(for: session, at: now).isEmpty)
        try WorkoutEngine.resume(&session, at: now.addingTimeInterval(100))
        XCTAssertEqual(WorkoutNotificationService.reminders(for: session, at: now.addingTimeInterval(100)).first?.deadline, now.addingTimeInterval(130))
    }
    func testUndoRetainsValuesClearsItsRestAndCannotEditFinishedHistory() throws {
        let exercise = Exercise(name: "卧推"); var session = WorkoutSession(status: .active, name: "撤销", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8)])])
        try WorkoutEngine.complete(&session, exercise: 0, set: 0, at: Date())
        XCTAssertNotNil(session.restDeadline)
        try WorkoutEngine.undoLastCompletion(&session)
        XCTAssertNil(session.restDeadline); XCTAssertNil(session.exercises[0].sets[0].completedAt); XCTAssertEqual(session.exercises[0].sets[0].loadKg, 20)
        session.status = .completed
        XCTAssertThrowsError(try WorkoutEngine.undoLastCompletion(&session))
    }
    func testSupersetCompletesOneRestAndUndoRecompletesExactlyOneRound() throws {
        let exercise = Exercise(name: "配对"), group = UUID(), now = Date()
        let items = (0..<2).map { SessionExercise(order: $0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8)], supersetID: group) }
        var session = WorkoutSession(status: .active, name: "超级组", exercises: items)
        try WorkoutEngine.complete(&session, exercise: 0, set: 0, at: now); XCTAssertNil(session.restDeadline)
        try WorkoutEngine.complete(&session, exercise: 1, set: 0, at: now.addingTimeInterval(1)); XCTAssertNotNil(session.restDeadline)
        try WorkoutEngine.undoLastCompletion(&session); XCTAssertNil(session.restDeadline)
        XCTAssertNotNil(session.exercises[0].sets[0].completedAt)
        try WorkoutEngine.complete(&session, exercise: 1, set: 0, at: now.addingTimeInterval(2))
        XCTAssertEqual(session.restDeadline, now.addingTimeInterval(92))
    }
    func testReplacementPreservesCompletedFactsAndClearsNewActualsAndIncompatibleTargets() async throws {
        let (actor, session, original) = try await fixture(); let exercise = session.exercises[0]
        try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: input(), pounds: false, miles: false)
        let before = try await actor.workout(session.stamp.id), replacement = Exercise(name: "平板支撑", measurement: .duration)
        try await actor.replaceWorkoutExercise(session.stamp.id, revision: before.stamp.revision, exerciseID: exercise.id, replacementID: replacement.stamp.id, catalog: [original, replacement])
        let after = try await actor.workout(session.stamp.id)
        XCTAssertEqual(after.exercises.count, 2)
        XCTAssertEqual(after.exercises[0].snapshot, before.exercises[0].snapshot)
        XCTAssertEqual(after.exercises[0].sets, [before.exercises[0].sets[0]])
        let fresh = after.exercises[1]
        XCTAssertEqual(fresh.snapshot.exerciseID, replacement.stamp.id); XCTAssertEqual(fresh.sets.count, 2)
        XCTAssertNil(fresh.plannedTargets?.minimumReps); XCTAssertNil(fresh.plannedTargets?.loadKg)
        XCTAssertTrue(fresh.sets.allSatisfy { WorkoutReuse.isBlank($0) })
        XCTAssertTrue(Set(fresh.sets.map(\.id)).isDisjoint(with: before.exercises[0].sets.map(\.id)))
        XCTAssertNil(after.restDeadline)
    }
    func testReplacementFailedSaveDoesNotPersistDependencyOrPartialChanges() async throws {
        let (actor, session, exercise) = try await fixture(); let replacement = Exercise(name: "替换")
        await actor.injectCommitFailure()
        do { try await actor.replaceWorkoutExercise(session.stamp.id, revision: session.stamp.revision, exerciseID: session.exercises[0].id, replacementID: replacement.stamp.id, catalog: [exercise, replacement]); XCTFail() } catch {}
        let saved = try await actor.workout(session.stamp.id), records = try await actor.snapshot()
        XCTAssertEqual(saved, session); XCTAssertFalse(records.contains { $0.id == replacement.stamp.id })
    }
    func testReplacementUnpairsAndRemovesPendingPausedTimerIDs() throws {
        let original = Exercise(name: "旧"), replacement = Exercise(name: "新"), group = UUID()
        let first = SessionExercise(order: 0, snapshot: ExerciseSnapshot(original), sets: [WorkoutSet(order: 0)], supersetID: group)
        let second = SessionExercise(order: 1, snapshot: ExerciseSnapshot(original), sets: [WorkoutSet(order: 0)], supersetID: group)
        var session = WorkoutSession(status: .paused, name: "替换", exercises: [first, second], pausedTimerSetIDs: [first.sets[0].id], pausedRestRemainingSeconds: 40)
        try ExerciseReplacement.apply(to: &session, exerciseID: first.id, replacement: replacement)
        XCTAssertTrue(session.exercises.allSatisfy { $0.supersetID == nil })
        XCTAssertEqual(session.pausedTimerSetIDs, []); XCTAssertNil(session.pausedRestRemainingSeconds)
    }
    func testReuseNeverOverwritesPartiallyEnteredValues() {
        let exercise = Exercise(name: "卧推"), now = Date()
        let prior = SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8, completedAt: now)])
        let entered = SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 99)])
        let result = WorkoutReuse.applying(WorkoutReference(sessionID: UUID(), date: "2026-11-25", exercise: prior), to: entered)
        XCTAssertEqual(result, entered)
    }
    func testUnitInputAndRunningTimerHaveIndependentSemantics() throws {
        let loaded = try input("100", "8").applying(to: WorkoutSet(order: 0), measurement: .assistedLoad, pounds: true, miles: false)
        XCTAssertEqual(loaded.loadKg!, 45.359237, accuracy: 0.000001)
        var timed = WorkoutSetInput(); timed.duration = "garbage"; timed.distance = "1"
        let now = Date(), running = WorkoutSet(order: 0, timerStartedAt: now, accumulatedSeconds: 10)
        let value = try timed.applying(to: running, measurement: .cardio, pounds: false, miles: true)
        XCTAssertEqual(value.timerStartedAt, now); XCTAssertEqual(value.distanceMeters, 1609.344); XCTAssertNil(value.durationSeconds)
    }
    func testAdvancedUncompletionOrDeletionCancelsItsPendingRest() async throws {
        let (actor, session, _) = try await fixture(), exercise = session.exercises[0]
        try await actor.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: exercise.id, setID: exercise.sets[0].id, input: input(), pounds: false, miles: false)
        var saved = try await actor.workout(session.stamp.id)
        XCTAssertNotNil(saved.restDeadline)
        saved.exercises[0].sets[0].completedAt = nil
        try await actor.saveWorkout(saved)
        let edited = try await actor.workout(session.stamp.id)
        XCTAssertNil(edited.restDeadline); XCTAssertNil(edited.restTriggerSetID)
    }
    func testUndoUsesCompletionOrderWhenTimestampsAreIdentical() throws {
        let exercise = Exercise(name: "同一时刻"), now = Date()
        var session = WorkoutSession(status: .active, name: "完成顺序", exercises: (0..<2).map {
            SessionExercise(order: $0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8)])
        })
        try WorkoutEngine.complete(&session, exercise: 1, set: 0, at: now)
        try WorkoutEngine.complete(&session, exercise: 0, set: 0, at: now)
        session = try RecordCoding.decode(WorkoutSession.self, from: RecordCoding.encode(session))
        try WorkoutEngine.undoLastCompletion(&session)
        XCTAssertNil(session.exercises[0].sets[0].completedAt)
        XCTAssertNotNil(session.exercises[1].sets[0].completedAt)
    }
    func testPausedRestAndUndoSurviveDiskReopenAndBackupRestore() async throws {
        let (source, session, exercise) = try await fixture(), item = session.exercises[0], now = Date()
        try await source.completeWorkoutSet(session.stamp.id, revision: session.stamp.revision, exerciseID: item.id, setID: item.sets[0].id, input: input(), pounds: false, miles: false, now: now)
        var paused = try await source.workout(session.stamp.id)
        try WorkoutEngine.pause(&paused, at: now.addingTimeInterval(10)); try await source.saveWorkout(paused)
        let exported = try await source.exportBackup()
        let directory = DataFixtures.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let disk = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
            try await disk.initializeProfile()
            let preview = try await disk.prepareImport(exported.data)
            _ = try await disk.importBackup(preview, acceptNewer: false)
        }
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        var restored = try await reopened.workout(session.stamp.id)
        XCTAssertEqual(restored.status, .paused)
        XCTAssertEqual(restored.pausedRestRemainingSeconds!, 80, accuracy: 0.001)
        XCTAssertEqual(restored.exercises[0].snapshot.exerciseID, exercise.stamp.id)
        XCTAssertEqual(restored.lastCompletedSetID, item.sets[0].id)
        try WorkoutEngine.undoLastCompletion(&restored); try await reopened.saveWorkout(restored)
        let undone = try await reopened.workout(session.stamp.id)
        XCTAssertNil(undone.pausedRestRemainingSeconds); XCTAssertNil(undone.exercises[0].sets[0].completedAt)
        XCTAssertEqual(undone.exercises[0].sets[0].loadKg, 20)
    }
    func testRestExtensionAtMaximumCanStillPauseAndValidate() async throws {
        let (actor, initial, _) = try await fixture(), now = Date()
        var session = initial; session.restDeadline = now.addingTimeInterval(86400)
        WorkoutEngine.extendRest(&session, at: now)
        XCTAssertEqual(session.restDeadline, now.addingTimeInterval(86400))
        try WorkoutEngine.pause(&session, at: now)
        try await actor.saveWorkout(session)
        let saved = try await actor.workout(session.stamp.id)
        XCTAssertEqual(saved.pausedRestRemainingSeconds, 86400)
    }
}
