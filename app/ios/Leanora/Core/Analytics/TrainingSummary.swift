import Foundation

struct TrainingSummary: Equatable, Sendable {
    var workouts = 0
    var completedSets = 0
    var volumeKg = 0.0
    var activeSeconds = 0.0
    var timedSeconds = 0.0
    var distanceMeters = 0.0
    var personalRecords: [UUID: Double] = [:]
    var bodyweightRepetitions = 0
    var assistedRepetitions = 0

    init(sessions: [WorkoutSession], from: String? = nil, through: String? = nil) {
        for session in sessions where session.stamp.deletedAt == nil && session.status == .completed && (from == nil || session.started.localDate >= from!) && (through == nil || session.started.localDate <= through!) {
            workouts += 1; activeSeconds += Self.activeDuration(session, at: session.endedAt ?? session.started.instant)
            for exercise in session.exercises {
                for set in exercise.sets where set.completedAt != nil {
                    completedSets += 1
                    if exercise.snapshot.measurement == .bodyweight { bodyweightRepetitions += set.repetitions ?? 0 }
                    if exercise.snapshot.measurement == .assistedLoad { assistedRepetitions += set.repetitions ?? 0 }
                    if [.duration, .cardio].contains(exercise.snapshot.measurement) { timedSeconds += set.durationSeconds ?? 0; distanceMeters += set.distanceMeters ?? 0 }
                    if exercise.snapshot.measurement == .externalLoad, set.kind == .working, let load = set.loadKg, let reps = set.repetitions {
                        volumeKg += load * Double(reps)
                        personalRecords[exercise.snapshot.exerciseID] = max(personalRecords[exercise.snapshot.exerciseID] ?? 0, load)
                    }
                }
            }
        }
    }

    static func activeDuration(_ session: WorkoutSession, at now: Date) -> Double {
        let end = session.endedAt ?? now
        let paused = session.pauses.reduce(0.0) { $0 + max(0, min($1.endedAt ?? end, end).timeIntervalSince($1.startedAt)) }
        return max(0, end.timeIntervalSince(session.started.instant) - paused)
    }
}
