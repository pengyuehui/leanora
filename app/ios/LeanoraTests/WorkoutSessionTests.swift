import XCTest
@testable import Leanora

final class WorkoutSessionTests: XCTestCase, @unchecked Sendable {
    private func fixture(measurement: ExerciseMeasurement = .externalLoad, now: Date = Date()) async throws -> (AppModelActor, WorkoutSession) {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let exercise = Exercise(name: "测试动作", measurement: measurement)
        let item = TrainingPlan.newItem(for: exercise, order: 0)
        let template = WorkoutTemplate(name: "测试训练", items: [item])
        try await actor.save([.exercise(exercise), .template(template)])
        return (actor, try await actor.startTraining(templateID: template.stamp.id, catalog: [], now: now))
    }
    func testEachSetSavesWithoutChangingPlanAndFinishIsIdempotent() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        try await actor.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.workout]))
        value.exercises[0].sets[0].loadKg = 20; value.exercises[0].sets[0].repetitions = 8
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: Date())
        try await actor.saveWorkout(value)
        let stored = try await actor.workout(value.stamp.id)
        XCTAssertEqual(stored.exercises[0].sets[0].loadKg, 20)
        XCTAssertNil(stored.exercises[0].plannedTargets?.loadKg)
        let finished = try await actor.finishWorkout(value.stamp.id)
        let repeated = try await actor.finishWorkout(value.stamp.id)
        XCTAssertEqual(finished, repeated)
        let jobs = try await actor.runtimeSnapshot(); XCTAssertEqual(jobs.filter { if case .job = $0 { return true }; return false }.count, 1)
        XCTAssertEqual(TrainingSummary(sessions: [finished]).volumeKg, 160)
    }
    func testPrefillUsesCompletedHistoryButDoesNotCompleteNewSets() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        value.exercises[0].sets[0].loadKg = 25; value.exercises[0].sets[0].repetitions = 9
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: Date()); try await actor.saveWorkout(value)
        _ = try await actor.finishWorkout(value.stamp.id)
        let next = try await actor.startTraining(templateID: value.templateID!, catalog: [])
        XCTAssertEqual(next.exercises[0].sets[0].loadKg, 25)
        XCTAssertEqual(next.exercises[0].sets[0].repetitions, 9)
        XCTAssertTrue(next.exercises[0].sets.allSatisfy { $0.completedAt == nil && $0.timerStartedAt == nil })
    }
    func testPauseResumeTimerAndRestAreIndependent() async throws {
        let start = Date().addingTimeInterval(-200)
        let (actor, initial) = try await fixture(measurement: .duration, now: start); var value = initial
        try WorkoutEngine.toggleTimer(&value, exercise: 0, set: 0, at: start)
        value.restDeadline = start.addingTimeInterval(45)
        try WorkoutEngine.pause(&value, at: start.addingTimeInterval(20))
        XCTAssertNil(value.exercises[0].sets[0].timerStartedAt)
        XCTAssertEqual(WorkoutEngine.elapsed(value.exercises[0].sets[0], at: start.addingTimeInterval(100)), 20)
        XCTAssertEqual(value.restDeadline, start.addingTimeInterval(45))
        try await actor.saveWorkout(value)
        var recovered = try await actor.workout(value.stamp.id)
        XCTAssertEqual(recovered.status, .paused); XCTAssertEqual(recovered.stamp.id, initial.stamp.id)
        try WorkoutEngine.resume(&recovered, at: start.addingTimeInterval(100))
        XCTAssertEqual(WorkoutEngine.elapsed(recovered.exercises[0].sets[0], at: start.addingTimeInterval(110)), 30)
        XCTAssertEqual(TrainingSummary.activeDuration(recovered, at: start.addingTimeInterval(110)), 30)
    }
    func testCrossMidnightAssignedToStartDate() async throws {
        let formatter = ISO8601DateFormatter(); let start = formatter.date(from: "2026-10-19T15:59:00Z")!
        let (actor, initial) = try await fixture(now: start); var value = initial
        value.exercises[0].sets[0].loadKg = 10; value.exercises[0].sets[0].repetitions = 5
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: start.addingTimeInterval(300)); try await actor.saveWorkout(value)
        let completed = try await actor.finishWorkout(value.stamp.id)
        XCTAssertEqual(completed.started.localDate, initial.started.localDate)
        XCTAssertEqual(TrainingSummary(sessions: [completed], from: initial.started.localDate, through: initial.started.localDate).workouts, 1)
    }
    func testSupersetStartsRestOnlyAfterBothExercisesInRound() async throws {
        let (_, initial) = try await fixture(); var value = initial
        let id = UUID(); value.exercises[0].supersetID = id
        var second = value.exercises[0]; second.id = UUID(); second.order = 1
        second.sets = second.sets.map { var set = $0; set.id = UUID(); return set }
        value.exercises.append(second)
        for i in 0...1 { value.exercises[i].sets[0].loadKg = 10; value.exercises[i].sets[0].repetitions = 8 }
        let now = Date(); try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: now); XCTAssertNil(value.restDeadline)
        try WorkoutEngine.complete(&value, exercise: 1, set: 0, at: now)
        XCTAssertEqual(value.restDeadline, now.addingTimeInterval(90))
    }
    func testFailedFinishRollsBackBothSessionAndJob() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        value.exercises[0].sets[0].loadKg = 10; value.exercises[0].sets[0].repetitions = 8
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: Date()); try await actor.saveWorkout(value)
        await actor.injectCommitFailure()
        do { _ = try await actor.finishWorkout(value.stamp.id); XCTFail() } catch {}
        let stored = try await actor.workout(value.stamp.id); XCTAssertEqual(stored.status, .active)
        let jobs = try await actor.runtimeSnapshot(); XCTAssertTrue(jobs.isEmpty)
    }
    func testEmptyFinishAndMissingActualValuesAreRejected() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        XCTAssertThrowsError(try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: Date()))
        do { _ = try await actor.finishWorkout(value.stamp.id); XCTFail() } catch {}
    }
    func testStaleSetEditDoesNotOverwriteNewValues() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        value.notes = "第一版"; try await actor.saveWorkout(value)
        value.notes = "过期编辑"
        do { try await actor.saveWorkout(value); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
    }
    @MainActor func testNotificationDeadlineRecoversFromSavedTimestampsAndExpiredRestIsNotRescheduled() async throws {
        let (_, initial) = try await fixture(measurement: .duration); var value = initial
        let now = Date(); value.restDeadline = now.addingTimeInterval(30)
        try WorkoutEngine.toggleTimer(&value, exercise: 0, set: 0, at: now.addingTimeInterval(-10))
        let reminders = WorkoutNotificationService.reminders(for: value, at: now)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.first { $0.id.contains("set.") }!.deadline.timeIntervalSince(now), 50, accuracy: 0.001)
        XCTAssertTrue(WorkoutNotificationService.reminders(for: value, at: now.addingTimeInterval(70)).isEmpty)
        value.status = .completed; XCTAssertTrue(WorkoutNotificationService.reminders(for: value, at: now).isEmpty)
    }
    func testRestoreGateAllowsLocalWorkoutCompletionWithoutHealthJobs() async throws {
        let (actor, initial) = try await fixture(); var value = initial
        let backup = try await actor.exportBackup(); let preview = try await actor.prepareImport(backup.data)
        _ = try await actor.importBackup(preview, acceptNewer: false)
        value = try await actor.workout(value.stamp.id)
        value.exercises[0].sets[0].loadKg = 10; value.exercises[0].sets[0].repetitions = 8
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: Date()); try await actor.saveWorkout(value)
        _ = try await actor.finishWorkout(value.stamp.id)
        let runtime = try await actor.runtimeSnapshot(); XCTAssertTrue(runtime.contains(.reconciliationRequired(true))); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
    }
    func testRetimeCompletedWorkoutMovesDayAndPreservesElapsedAndPauseIntervals() async throws {
        let (actor, initial) = try await fixture(now: Date().addingTimeInterval(-600)); var value = initial
        value.exercises[0].sets[0].loadKg = 20; value.exercises[0].sets[0].repetitions = 8
        try WorkoutEngine.complete(&value, exercise: 0, set: 0, at: value.started.instant.addingTimeInterval(30))
        try WorkoutEngine.pause(&value, at: value.started.instant.addingTimeInterval(40))
        try WorkoutEngine.resume(&value, at: value.started.instant.addingTimeInterval(60))
        try await actor.saveWorkout(value)
        let original = try await actor.finishWorkout(value.stamp.id)
        let newStart = original.started.instant.addingTimeInterval(-86400)
        try await actor.retimeWorkout(original.stamp.id, revision: original.stamp.revision, started: newStart, timeZoneID: "Asia/Shanghai")
        let moved = try await actor.workout(original.stamp.id)
        XCTAssertEqual(moved.started.localDate, RecordMoment(newStart, timeZoneID: "Asia/Shanghai").localDate)
        XCTAssertEqual(TrainingSummary(sessions: [moved]).activeSeconds, TrainingSummary(sessions: [original]).activeSeconds, accuracy: 0.001)
        XCTAssertEqual(moved.exercises[0].sets[0].completedAt!.timeIntervalSince(original.exercises[0].sets[0].completedAt!), -86400, accuracy: 0.001)
    }
    func testDiskReopenKeepsSamePausedWorkoutAndRunningTimerState() async throws {
        let directory = DataFixtures.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let id: UUID
        do {
            let actor = AppModelActor(modelContainer: try StoreFactory.open(directory: directory)); try await actor.initializeProfile()
            let exercise = Exercise(name: "计时", measurement: .duration)
            let template = WorkoutTemplate(name: "磁盘恢复", items: [TrainingPlan.newItem(for: exercise, order: 0)])
            try await actor.save([.exercise(exercise), .template(template)])
            var value = try await actor.startTraining(templateID: template.stamp.id, catalog: [])
            id = value.stamp.id
            try WorkoutEngine.toggleTimer(&value, exercise: 0, set: 0, at: Date().addingTimeInterval(-10))
            try WorkoutEngine.pause(&value, at: Date()); try await actor.saveWorkout(value)
        }
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let stored = try await reopened.workout(id)
        XCTAssertEqual(stored.status, .paused); XCTAssertEqual(stored.pausedTimerSetIDs, [stored.exercises[0].sets[0].id])
        XCTAssertEqual(stored.exercises[0].sets[0].accumulatedSeconds, 10, accuracy: 0.1)
        let resumed = try await reopened.startTraining(templateID: stored.templateID!, catalog: []); XCTAssertEqual(resumed.stamp.id, id)
    }
    @MainActor func testScheduledReminderHonorsMovedAndStartedOccurrences() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = ISO8601DateFormatter().date(from: "2026-10-20T00:00:00Z")!
        let day = RecordMoment(now, timeZoneID: calendar.timeZone.identifier).localDate
        let template = WorkoutTemplate(name: "每周训练", scheduledWeekdays: [TrainingPlan.weekday(day)])
        let reminders = TrainingReminderService.upcoming(templates: [template], changes: [], sessions: [], hour: 18, minute: 0, now: now, calendar: calendar)
        XCTAssertEqual(reminders.count, 2)
        let session = WorkoutSession(status: .active, templateID: template.stamp.id, name: "已开始", scheduleOriginDate: day)
        XCTAssertEqual(TrainingReminderService.upcoming(templates: [template], changes: [], sessions: [session], hour: 18, minute: 0, now: now, calendar: calendar).count, 1)
        let change = WorkoutDayChange(templateID: template.stamp.id, originDate: day, destinationDate: "2026-10-21", timeZoneID: calendar.timeZone.identifier)
        let moved = TrainingReminderService.upcoming(templates: [template], changes: [change], sessions: [], hour: 18, minute: 0, now: now, calendar: calendar)
        XCTAssertFalse(moved.contains { $0.id.hasSuffix(day) }); XCTAssertTrue(moved.contains { $0.id.hasSuffix("2026-10-21") })
    }
    func testMalformedPausedSessionRejectedBeforeItCanReachFinish() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        do { try await actor.save([.session(WorkoutSession(status: .paused, name: "损坏记录"))]); XCTFail() }
        catch { XCTAssertEqual(error as? DataProblem, .invalid("暂停状态缺少区间")) }
    }
    func testPrefillKeepsRepeatedTemplateItemsIndependent() {
        let exercise = Exercise(name: "卧推"), first = UUID(), second = UUID(), now = Date()
        let items = [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8, completedAt: now)], templateItemID: first),
                     SessionExercise(order: 1, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 30, repetitions: 5, completedAt: now)], templateItemID: second)]
        let history = WorkoutSession(started: RecordMoment(now.addingTimeInterval(-60)), endedAt: now, status: .completed, name: "历史", exercises: items)
        var current = history; current.stamp = RecordStamp(); current.started = RecordMoment(now.addingTimeInterval(10)); current.status = .active; current.endedAt = nil
        for i in current.exercises.indices { current.exercises[i].sets = [WorkoutSet(order: 0)] }
        let result = WorkoutEngine.prefilled(current, history: [history])
        XCTAssertEqual(result.exercises[0].sets[0].loadKg, 20); XCTAssertEqual(result.exercises[1].sets[0].loadKg, 30)
        XCTAssertTrue(result.exercises.flatMap(\.sets).allSatisfy { $0.completedAt == nil })
    }
}
