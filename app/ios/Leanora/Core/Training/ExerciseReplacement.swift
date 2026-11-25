import Foundation

struct ExerciseReplacementPreview: Sendable {
    let sourceName: String
    let replacementName: String
    let completedSets: Int
    let pendingSets: Int
    let clearsTargets: Bool
    let unpairsSuperset: Bool
}

enum ExerciseReplacement {
    static func preview(_ source: SessionExercise, with replacement: Exercise) throws -> ExerciseReplacementPreview {
        guard !replacement.isArchived, replacement.stamp.deletedAt == nil else { throw TrainingProblem.archivedExercise }
        guard source.snapshot.exerciseID != replacement.stamp.id else { throw DataProblem.invalid("请选择其他动作") }
        let completed = source.sets.filter { $0.completedAt != nil }.count
        guard source.sets.count > completed else { throw DataProblem.invalid("这个动作没有待完成组") }
        return ExerciseReplacementPreview(sourceName: source.snapshot.name, replacementName: replacement.name,
            completedSets: completed, pendingSets: source.sets.count - completed,
            clearsTargets: source.snapshot.measurement != replacement.measurement, unpairsSuperset: source.supersetID != nil)
    }

    static func apply(to session: inout WorkoutSession, exerciseID: UUID, replacement: Exercise) throws {
        guard [.active, .paused].contains(session.status),
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }) else { throw TrainingProblem.missingRecord }
        let source = session.exercises[index], preview = try preview(source, with: replacement)
        let pending = source.sets.filter { $0.completedAt == nil }
        var targets = source.plannedTargets
        targets?.sets = pending.count
        if preview.clearsTargets, let old = targets {
            targets = PlannedTargets(sets: pending.count, restSeconds: old.restSeconds)
        }
        let fresh = SessionExercise(order: index, snapshot: ExerciseSnapshot(replacement),
            sets: pending.enumerated().map { WorkoutSet(order: $0.offset, kind: $0.element.kind) }, plannedTargets: targets)
        var completed = source
        completed.sets = source.sets.filter { $0.completedAt != nil }
        for j in completed.sets.indices { completed.sets[j].order = j }
        session.exercises.remove(at: index)
        session.exercises.insert(contentsOf: completed.sets.isEmpty ? [fresh] : [completed, fresh], at: index)
        for i in session.exercises.indices {
            session.exercises[i].order = i
            if let group = source.supersetID, session.exercises[i].supersetID == group { session.exercises[i].supersetID = nil }
        }
        let removedIDs = Set(pending.map(\.id))
        session.pausedTimerSetIDs = session.pausedTimerSetIDs?.filter { !removedIDs.contains($0) }
        WorkoutEngine.clearRest(&session)
    }
}
