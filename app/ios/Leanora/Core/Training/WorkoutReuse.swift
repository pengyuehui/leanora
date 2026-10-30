import Foundation

struct WorkoutReference: Sendable {
    let sessionID: UUID
    let date: String
    let exercise: SessionExercise
}

enum WorkoutReuse {
    static func reference(for exercise: SessionExercise, in current: WorkoutSession, history: [WorkoutSession]) -> WorkoutReference? {
        let occurrence = current.exercises.sorted { $0.order < $1.order }
            .filter { $0.snapshot.exerciseID == exercise.snapshot.exerciseID }
            .firstIndex { $0.id == exercise.id } ?? 0
        let eligible = history.filter {
            $0.stamp.id != current.stamp.id && $0.status == .completed && $0.stamp.deletedAt == nil &&
            $0.endedAt.map { $0 < current.started.instant } == true
        }.sorted {
            if $0.endedAt != $1.endedAt { return $0.endedAt! > $1.endedAt! }
            return $0.stamp.id.uuidString < $1.stamp.id.uuidString
        }
        for session in eligible {
            let matches = session.exercises.sorted { $0.order < $1.order }.filter {
                $0.snapshot.exerciseID == exercise.snapshot.exerciseID && $0.snapshot.measurement == exercise.snapshot.measurement &&
                $0.sets.contains { $0.completedAt != nil }
            }
            let exact = exercise.templateItemID.flatMap { id in matches.first { $0.templateItemID == id } }
            if let prior = exact ?? (matches.indices.contains(occurrence) ? matches[occurrence] : nil) {
                return WorkoutReference(sessionID: session.stamp.id, date: session.started.localDate, exercise: prior)
            }
        }
        return nil
    }

    static func previousSet(for set: WorkoutSet, in exercise: SessionExercise, reference: WorkoutReference) -> WorkoutSet? {
        let index = exercise.sets.sorted { $0.order < $1.order }.filter { $0.kind == set.kind }.firstIndex { $0.id == set.id } ?? 0
        let values = reference.exercise.sets.filter { $0.completedAt != nil && $0.kind == set.kind }.sorted { $0.order < $1.order }
        return values.indices.contains(index) ? values[index] : values.last
    }

    static func applying(_ reference: WorkoutReference, to exercise: SessionExercise) -> SessionExercise {
        guard reference.exercise.snapshot.exerciseID == exercise.snapshot.exerciseID,
              reference.exercise.snapshot.measurement == exercise.snapshot.measurement else { return exercise }
        var result = exercise
        for i in result.sets.indices {
            let current = result.sets[i]
            guard current.completedAt == nil, current.timerStartedAt == nil, current.accumulatedSeconds == 0,
                  let previous = previousSet(for: current, in: exercise, reference: reference) else { continue }
            result.sets[i].loadKg = previous.loadKg
            result.sets[i].repetitions = previous.repetitions
            result.sets[i].durationSeconds = previous.durationSeconds
            result.sets[i].distanceMeters = previous.distanceMeters
        }
        return result
    }

    static func repeated(_ source: WorkoutSession, exercises: [Exercise], now: Date, timeZoneID: String) throws -> WorkoutSession {
        guard source.status == .completed, source.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        let available = Dictionary(uniqueKeysWithValues: exercises.map { ($0.stamp.id, $0) })
        var values: [SessionExercise] = []
        for item in source.exercises.sorted(by: { $0.order < $1.order }) {
            let completed = item.sets.filter { $0.completedAt != nil }.sorted { $0.order < $1.order }
            guard !completed.isEmpty else { continue }
            let exercise = try usable(item.snapshot, in: available)
            let sets = completed.enumerated().map { index, old in
                WorkoutSet(order: index, kind: old.kind, loadKg: old.loadKg, repetitions: old.repetitions,
                           durationSeconds: old.durationSeconds, distanceMeters: old.distanceMeters)
            }
            var targets = item.plannedTargets; targets?.sets = sets.count
            values.append(SessionExercise(order: values.count, snapshot: ExerciseSnapshot(exercise), sets: sets,
                                          supersetID: item.supersetID, notes: item.notes, plannedTargets: targets))
        }
        guard !values.isEmpty else { throw DataProblem.invalid("没有已完成组可供再练") }
        remapPairs(&values)
        return WorkoutSession(started: RecordMoment(now, timeZoneID: timeZoneID), status: .active, name: source.name, exercises: values, notes: source.notes)
    }

    static func template(from session: WorkoutSession, exercises: [Exercise], original: WorkoutTemplate? = nil) throws -> WorkoutTemplate {
        guard session.status == .completed, session.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        if let original {
            guard original.stamp.deletedAt == nil, original.stamp.id == session.templateID,
                  original.stamp.revision == session.templateRevision else { throw DataProblem.revisionConflict }
        }
        let available = Dictionary(uniqueKeysWithValues: exercises.map { ($0.stamp.id, $0) })
        var template = original ?? WorkoutTemplate(name: session.name, notes: session.notes)
        template.items = []
        var groups: [UUID: UUID] = [:]
        for item in session.exercises.sorted(by: { $0.order < $1.order }) {
            let completed = item.sets.filter { $0.completedAt != nil && $0.kind == .working }.sorted { $0.order < $1.order }
            guard let first = completed.first else { continue }
            _ = try usable(item.snapshot, in: available)
            let group = item.supersetID.map { id in
                if groups[id] == nil { groups[id] = UUID() }
                return groups[id]!
            }
            template.items.append(TemplateItem(exerciseID: item.snapshot.exerciseID, order: template.items.count,
                plannedSets: completed.count, minimumReps: first.repetitions, maximumReps: first.repetitions,
                loadKg: first.loadKg, durationSeconds: first.durationSeconds, distanceMeters: first.distanceMeters,
                restSeconds: item.plannedTargets?.restSeconds ?? 90, supersetID: group))
        }
        guard !template.items.isEmpty else { throw DataProblem.invalid("没有已完成正式组可保存为模板") }
        let counts = Dictionary(grouping: template.items.compactMap(\.supersetID), by: { $0 }).mapValues(\.count)
        for i in template.items.indices {
            if let id = template.items[i].supersetID, counts[id] != 2 { template.items[i].supersetID = nil }
        }
        return template
    }

    static func recentExerciseIDs(in sessions: [WorkoutSession], limit: Int = 20) -> [UUID] {
        guard limit > 0 else { return [] }
        let history = sessions.filter { $0.status == .completed && $0.stamp.deletedAt == nil }.sorted {
            let left = $0.endedAt ?? $0.started.instant, right = $1.endedAt ?? $1.started.instant
            return left == right ? $0.stamp.id.uuidString < $1.stamp.id.uuidString : left > right
        }
        var seen = Set<UUID>(), result: [UUID] = []
        for session in history {
            for exercise in session.exercises.sorted(by: { $0.order < $1.order }) where exercise.sets.contains(where: { $0.completedAt != nil }) {
                let id = exercise.snapshot.exerciseID
                if seen.insert(id).inserted { result.append(id); if result.count == limit { return result } }
            }
        }
        return result
    }

    static func removeExercise(_ id: UUID, from session: inout WorkoutSession) throws {
        guard [.active, .paused].contains(session.status), let index = session.exercises.firstIndex(where: { $0.id == id }) else { throw TrainingProblem.missingRecord }
        let group = session.exercises[index].supersetID
        session.exercises.remove(at: index)
        for i in session.exercises.indices {
            session.exercises[i].order = i
            if let group, session.exercises[i].supersetID == group { session.exercises[i].supersetID = nil }
        }
        let live = Set(session.exercises.flatMap(\.sets).map(\.id))
        session.pausedTimerSetIDs = session.pausedTimerSetIDs?.filter { live.contains($0) }
        session.restDeadline = nil
    }

    private static func usable(_ snapshot: ExerciseSnapshot, in exercises: [UUID: Exercise]) throws -> Exercise {
        guard let value = exercises[snapshot.exerciseID], value.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        guard !value.isArchived else { throw TrainingProblem.archivedExercise }
        guard value.measurement == snapshot.measurement else { throw DataProblem.invalid("动作记录类型已改变，请先替换动作") }
        return value
    }

    private static func remapPairs(_ values: inout [SessionExercise]) {
        let counts = Dictionary(grouping: values.compactMap(\.supersetID), by: { $0 }).mapValues(\.count)
        var groups: [UUID: UUID] = [:]
        for i in values.indices {
            if let id = values[i].supersetID, counts[id] == 2 {
                if groups[id] == nil { groups[id] = UUID() }
                values[i].supersetID = groups[id]
            } else { values[i].supersetID = nil }
        }
    }
}
