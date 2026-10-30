import Foundation

extension AppModelActor {
    func startFreeTraining(now: Date = Date(), timeZoneID: String = TimeZone.current.identifier) throws -> WorkoutSession {
        if let active = try activeWorkout() { return active }
        let value = WorkoutSession(started: RecordMoment(now, timeZoneID: timeZoneID), status: .active, name: "自由训练")
        try save([.session(value)])
        return value
    }

    func repeatWorkout(_ id: UUID, catalog: [Exercise], now: Date = Date(), timeZoneID: String = TimeZone.current.identifier) throws -> WorkoutSession {
        if let active = try activeWorkout() { return active }
        let value = try WorkoutReuse.repeated(workout(id), exercises: trainingExercises(catalog: catalog), now: now, timeZoneID: timeZoneID)
        try save([.session(value)])
        return value
    }

    func addExerciseToWorkout(_ id: UUID, revision: Int, exerciseID: UUID, catalog: [Exercise], now: Date = Date()) throws {
        var value = try workout(id)
        guard value.stamp.revision == revision, [.active, .paused].contains(value.status) else { throw DataProblem.revisionConflict }
        let records = try snapshot()
        guard let exercise = try trainingExercises(catalog: catalog).first(where: { $0.stamp.id == exerciseID }), exercise.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        guard !exercise.isArchived else { throw TrainingProblem.archivedExercise }
        let plan = TrainingPlan.newItem(for: exercise, order: value.exercises.count)
        value.exercises.append(SessionExercise(order: value.exercises.count, snapshot: ExerciseSnapshot(exercise),
            sets: (0..<plan.plannedSets).map { WorkoutSet(order: $0) },
            plannedTargets: PlannedTargets(sets: plan.plannedSets, minimumReps: plan.minimumReps, maximumReps: plan.maximumReps,
                durationSeconds: plan.durationSeconds, distanceMeters: plan.distanceMeters, restSeconds: plan.restSeconds)))
        let i = value.exercises.count - 1
        let history = records.compactMap { if case .session(let v) = $0 { return v }; return nil }
        if let reference = WorkoutReuse.reference(for: value.exercises[i], in: value, history: history) {
            value.exercises[i] = WorkoutReuse.applying(reference, to: value.exercises[i])
        }
        value.stamp.revision += 1; value.stamp.updatedAt = max(now, value.stamp.updatedAt)
        let dependencies: [BusinessRecord] = records.contains(where: { $0.id == exerciseID && $0.kind == "exercise" }) ? [] : [.exercise(exercise)]
        try saveWithHealthIntent(dependencies + [.session(value)])
    }

    private func activeWorkout() throws -> WorkoutSession? {
        try snapshot().compactMap { record -> WorkoutSession? in
            if case .session(let v) = record, v.stamp.deletedAt == nil, [.active, .paused].contains(v.status) { return v }
            return nil
        }.first
    }

    func workout(_ id: UUID) throws -> WorkoutSession {
        guard case .session(let value) = try snapshot().first(where: { $0.id == id }), value.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        return value
    }

    func saveWorkout(_ draft: WorkoutSession, now: Date = Date()) throws {
        let old = try workout(draft.stamp.id)
        guard old.stamp.revision == draft.stamp.revision, old.status != .abandoned,
              old.status == .completed ? draft.status == .completed : [.active, .paused].contains(draft.status),
              old.started.localDate == draft.started.localDate, old.started.timeZoneID == draft.started.timeZoneID,
              abs(old.started.instant.timeIntervalSince(draft.started.instant)) < 0.001 else { throw DataProblem.revisionConflict }
        var value = draft
        for item in value.exercises { for set in item.sets where set.completedAt != nil { try WorkoutEngine.validateActual(set, measurement: item.snapshot.measurement) } }
        value.stamp.revision += 1; value.stamp.updatedAt = max(now, old.stamp.updatedAt)
        try saveWithHealthIntent([.session(value)])
    }

    func finishWorkout(_ id: UUID, now: Date = Date()) throws -> WorkoutSession {
        var value = try workout(id)
        if value.status == .completed { return value }
        guard [.active, .paused].contains(value.status), value.exercises.contains(where: { $0.sets.contains { $0.completedAt != nil } }) else { throw DataProblem.invalid("请至少完成一组后结束训练") }
        let end = max(now, max(value.stamp.updatedAt, value.started.instant))
        WorkoutEngine.stopTimers(&value, at: end)
        if value.status == .paused {
            guard !value.pauses.isEmpty else { throw DataProblem.invalid("暂停区间") }
            value.pauses[value.pauses.count - 1].endedAt = end
        }
        value.status = .completed; value.endedAt = end; value.restDeadline = nil
        value.pausedTimerSetIDs = nil
        value.stamp.revision += 1; value.stamp.updatedAt = end
        try saveWithHealthIntent([.session(value)])
        return try workout(id)
    }

    func deleteWorkout(_ id: UUID, revision: Int, deleteHealthCopies: Bool = false) throws {
        var value = try workout(id)
        guard value.status == .completed, value.stamp.revision == revision else { throw DataProblem.revisionConflict }
        value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt); value.stamp.deletedAt = value.stamp.updatedAt
        try saveWithHealthIntent([.session(value)], deleteHealthCopies: deleteHealthCopies)
    }

    func retimeWorkout(_ id: UUID, revision: Int, started: Date, timeZoneID: String) throws {
        var value = try workout(id)
        guard value.status == .completed, value.stamp.revision == revision else { throw DataProblem.revisionConflict }
        let offset = started.timeIntervalSince(value.started.instant)
        value.started = RecordMoment(started, timeZoneID: timeZoneID)
        value.endedAt = value.endedAt?.addingTimeInterval(offset)
        value.pauses = value.pauses.map { PauseInterval(startedAt: $0.startedAt.addingTimeInterval(offset), endedAt: $0.endedAt?.addingTimeInterval(offset)) }
        for i in value.exercises.indices {
            for j in value.exercises[i].sets.indices { value.exercises[i].sets[j].completedAt = value.exercises[i].sets[j].completedAt?.addingTimeInterval(offset) }
        }
        value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt)
        try saveWithHealthIntent([.session(value)])
    }
}
