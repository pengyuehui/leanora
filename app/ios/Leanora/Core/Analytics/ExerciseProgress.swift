import Foundation

struct ExerciseProgressEntry: Identifiable, Sendable {
    var session: WorkoutSession
    var exercises: [SessionExercise]
    var measurement: ExerciseMeasurement
    var id: UUID { session.stamp.id }
    var sets: [WorkoutSet] { exercises.flatMap { $0.sets.filter { $0.kind == .working && $0.completedAt != nil }.sorted { $0.order < $1.order } } }
    var volumeKg: Double? {
        guard measurement == .externalLoad else { return nil }
        return sets.reduce(0) { $0 + ($1.loadKg ?? 0) * Double($1.repetitions ?? 0) }
    }
    var bestLoadKg: Double? { measurement == .externalLoad ? sets.compactMap(\.loadKg).max() : nil }
    var repetitions: Int { sets.reduce(0) { $0 + ($1.repetitions ?? 0) } }
    var duration: Double { sets.reduce(0) { $0 + ($1.durationSeconds ?? 0) } }
    var distance: Double { sets.reduce(0) { $0 + ($1.distanceMeters ?? 0) } }
}

enum ExerciseProgress {
    static func history(exerciseID: UUID, measurement: ExerciseMeasurement, sessions: [WorkoutSession]) -> [ExerciseProgressEntry] {
        sessions.filter { $0.status == .completed && $0.stamp.deletedAt == nil }.compactMap { session in
            let matches = session.exercises.filter {
                $0.snapshot.exerciseID == exerciseID && $0.snapshot.measurement == measurement &&
                $0.sets.contains { $0.kind == .working && $0.completedAt != nil }
            }.sorted { $0.order < $1.order }
            return matches.isEmpty ? nil : ExerciseProgressEntry(session: session, exercises: matches, measurement: measurement)
        }.sorted {
            $0.session.started.instant == $1.session.started.instant ? $0.id.uuidString < $1.id.uuidString : $0.session.started.instant > $1.session.started.instant
        }
    }
}
