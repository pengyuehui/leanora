import Foundation

enum WorkoutEngine {
    static func elapsed(_ set: WorkoutSet, at now: Date) -> Double {
        set.accumulatedSeconds + (set.timerStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    static func pause(_ session: inout WorkoutSession, at now: Date) throws {
        guard session.status == .active else { throw DataProblem.invalid("训练状态") }
        session.pausedTimerSetIDs = session.exercises.flatMap(\.sets).filter { $0.timerStartedAt != nil }.map(\.id)
        stopTimers(&session, at: now)
        session.pauses.append(PauseInterval(startedAt: now)); session.status = .paused
    }

    static func resume(_ session: inout WorkoutSession, at now: Date) throws {
        guard session.status == .paused, !session.pauses.isEmpty else { throw DataProblem.invalid("训练状态") }
        session.pauses[session.pauses.count - 1].endedAt = now; session.status = .active
        for i in session.exercises.indices {
            for j in session.exercises[i].sets.indices where session.pausedTimerSetIDs?.contains(session.exercises[i].sets[j].id) == true && session.exercises[i].sets[j].completedAt == nil {
                session.exercises[i].sets[j].timerStartedAt = now
            }
        }
        session.pausedTimerSetIDs = nil
    }

    static func stopTimers(_ session: inout WorkoutSession, at now: Date) {
        for i in session.exercises.indices {
            for j in session.exercises[i].sets.indices where session.exercises[i].sets[j].timerStartedAt != nil {
                let value = elapsed(session.exercises[i].sets[j], at: now)
                session.exercises[i].sets[j].accumulatedSeconds = value
                session.exercises[i].sets[j].durationSeconds = value
                session.exercises[i].sets[j].timerStartedAt = nil
            }
        }
    }

    static func toggleTimer(_ session: inout WorkoutSession, exercise: Int, set: Int, at now: Date) throws {
        guard session.status == .active, session.exercises.indices.contains(exercise),
              session.exercises[exercise].sets.indices.contains(set),
              [.duration, .cardio].contains(session.exercises[exercise].snapshot.measurement),
              session.exercises[exercise].sets[set].completedAt == nil else { throw DataProblem.invalid("计时组") }
        if session.exercises[exercise].sets[set].timerStartedAt != nil {
            let value = elapsed(session.exercises[exercise].sets[set], at: now)
            session.exercises[exercise].sets[set].durationSeconds = value
            session.exercises[exercise].sets[set].accumulatedSeconds = value
            session.exercises[exercise].sets[set].timerStartedAt = nil
        } else { session.exercises[exercise].sets[set].timerStartedAt = now }
    }

    static func complete(_ session: inout WorkoutSession, exercise: Int, set: Int, at now: Date) throws {
        guard session.status == .active, session.exercises.indices.contains(exercise), session.exercises[exercise].sets.indices.contains(set) else { throw DataProblem.invalid("训练状态") }
        var value = session.exercises[exercise].sets[set]
        guard value.completedAt == nil else { return }
        if value.timerStartedAt != nil {
            value.accumulatedSeconds = elapsed(value, at: now); value.durationSeconds = value.accumulatedSeconds; value.timerStartedAt = nil
        }
        try validateActual(value, measurement: session.exercises[exercise].snapshot.measurement)
        value.completedAt = now; session.exercises[exercise].sets[set] = value
        let item = session.exercises[exercise]
        let pair = item.supersetID.map { id in session.exercises.filter { $0.supersetID == id } } ?? [item]
        let roundComplete = pair.allSatisfy { $0.sets.count <= set || $0.sets[set].completedAt != nil }
        if roundComplete { session.restDeadline = now.addingTimeInterval(item.plannedTargets?.restSeconds ?? 90) }
    }

    static func validateActual(_ set: WorkoutSet, measurement: ExerciseMeasurement) throws {
        switch measurement {
        case .externalLoad, .assistedLoad:
            guard let load = set.loadKg, load >= 0, let reps = set.repetitions, reps > 0 else { throw DataProblem.invalid("请填写实际负重和次数") }
        case .bodyweight:
            guard let reps = set.repetitions, reps > 0 else { throw DataProblem.invalid("请填写实际次数") }
        case .duration, .cardio:
            guard let duration = set.durationSeconds, duration > 0 else { throw DataProblem.invalid("请填写或计时得到实际时长") }
        }
    }

    static func prefilled(_ session: WorkoutSession, history: [WorkoutSession]) -> WorkoutSession {
        var session = session
        let history = history.filter { $0.status == .completed && $0.stamp.deletedAt == nil }.sorted { ($0.endedAt ?? $0.started.instant) > ($1.endedAt ?? $1.started.instant) }
        for i in session.exercises.indices {
            let exercise = session.exercises[i]
            let prior = history.lazy.compactMap { session -> SessionExercise? in
                let matches = session.exercises.filter { $0.snapshot.exerciseID == exercise.snapshot.exerciseID && $0.sets.contains { $0.completedAt != nil } }
                return matches.first { exercise.templateItemID != nil && $0.templateItemID == exercise.templateItemID } ?? matches.last
            }.first
            for j in session.exercises[i].sets.indices {
                let values = prior?.sets.filter { $0.completedAt != nil } ?? []
                if let old = values.first(where: { $0.order == j }) ?? values.last {
                    session.exercises[i].sets[j].loadKg = old.loadKg
                    session.exercises[i].sets[j].repetitions = old.repetitions
                    session.exercises[i].sets[j].durationSeconds = old.durationSeconds
                    session.exercises[i].sets[j].distanceMeters = old.distanceMeters
                }
            }
        }
        return session
    }
}
