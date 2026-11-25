import Foundation

enum WorkoutEngine {
    static func elapsed(_ set: WorkoutSet, at now: Date) -> Double {
        set.accumulatedSeconds + (set.timerStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    static func pause(_ session: inout WorkoutSession, at now: Date) throws {
        guard session.status == .active else { throw DataProblem.invalid("训练状态") }
        session.pausedTimerSetIDs = session.exercises.flatMap(\.sets).filter { $0.timerStartedAt != nil }.map(\.id)
        session.pausedRestRemainingSeconds = session.restDeadline.map { min(86400, max(0, $0.timeIntervalSince(now))) }
        session.restDeadline = nil
        stopTimers(&session, at: now)
        session.pauses.append(PauseInterval(startedAt: now)); session.status = .paused
    }

    static func resume(_ session: inout WorkoutSession, at now: Date) throws {
        guard session.status == .paused, !session.pauses.isEmpty else { throw DataProblem.invalid("训练状态") }
        let remaining = pausedRestRemaining(in: session)
        session.pauses[session.pauses.count - 1].endedAt = now; session.status = .active
        // Old paused payloads may still contain a deadline. Recover its remaining
        // time at the pause instant rather than counting the pause as rest.
        session.restDeadline = remaining.flatMap { $0 > 0 ? now.addingTimeInterval($0) : nil }
        session.pausedRestRemainingSeconds = nil
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
        session.lastCompletedSetID = value.id
        let item = session.exercises[exercise]
        let pair = item.supersetID.map { id in session.exercises.filter { $0.supersetID == id } } ?? [item]
        let roundComplete = pair.allSatisfy { $0.sets.count <= set || $0.sets[set].completedAt != nil }
        if roundComplete {
            session.restDeadline = now.addingTimeInterval(item.plannedTargets?.restSeconds ?? 90)
            session.restTriggerSetID = value.id
        }
    }

    static func clearRest(_ session: inout WorkoutSession) {
        session.restDeadline = nil; session.pausedRestRemainingSeconds = nil; session.restTriggerSetID = nil
    }

    static func pausedRestRemaining(in session: WorkoutSession) -> Double? {
        guard session.status == .paused else { return nil }
        return session.pausedRestRemainingSeconds ?? session.restDeadline.flatMap { deadline in
            session.pauses.last.map { min(86400, max(0, deadline.timeIntervalSince($0.startedAt))) }
        }
    }

    static func extendRest(_ session: inout WorkoutSession, at now: Date) {
        guard session.status == .active else { return }
        let remaining = max(0, session.restDeadline?.timeIntervalSince(now) ?? 0)
        session.restDeadline = now.addingTimeInterval(min(86400, remaining + 30))
    }

    static func latestCompletedSet(in session: WorkoutSession) -> (exercise: Int, set: Int)? {
        if let id = session.lastCompletedSetID {
            for i in session.exercises.indices {
                if let j = session.exercises[i].sets.firstIndex(where: { $0.id == id && $0.completedAt != nil }) { return (i, j) }
            }
        }
        var result: (exercise: Int, set: Int)?
        var latest: Date?
        for i in session.exercises.indices {
            for j in session.exercises[i].sets.indices {
                if let date = session.exercises[i].sets[j].completedAt, latest == nil || date >= latest! {
                    latest = date; result = (i, j)
                }
            }
        }
        return result
    }

    static func undoLastCompletion(_ session: inout WorkoutSession) throws {
        guard [.active, .paused].contains(session.status), let index = latestCompletedSet(in: session) else {
            throw DataProblem.invalid("没有可撤销的完成组")
        }
        let id = session.exercises[index.exercise].sets[index.set].id
        session.exercises[index.exercise].sets[index.set].completedAt = nil
        session.lastCompletedSetID = nil
        // Preserve entered actual values; undo never resumes an action timer.
        if session.restTriggerSetID == nil || session.restTriggerSetID == id { clearRest(&session) }
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
        for i in session.exercises.indices {
            if let reference = WorkoutReuse.reference(for: session.exercises[i], in: session, history: history) {
                session.exercises[i] = WorkoutReuse.applying(reference, to: session.exercises[i])
            }
        }
        return session
    }
}
