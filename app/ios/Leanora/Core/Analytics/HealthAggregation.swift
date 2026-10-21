import Foundation

enum HealthAggregation {
    static func overlaps(_ local: WorkoutSession, _ external: ExternalWorkout) -> Bool {
        local.status == .completed && local.stamp.deletedAt == nil &&
        min(local.endedAt ?? local.started.instant, external.endedAt) > max(local.started.instant, external.started.instant)
    }
    static func primaryDuration(local: WorkoutSession, external: ExternalWorkout, choice: HealthWorkoutPrimary) -> Double {
        choice == .local ? TrainingSummary.activeDuration(local, at: local.endedAt ?? Date()) : external.durationSeconds ?? max(0, external.endedAt.timeIntervalSince(external.started.instant))
    }
}
