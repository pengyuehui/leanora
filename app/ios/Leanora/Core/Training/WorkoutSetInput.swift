import Foundation

struct WorkoutSetInput: Equatable, Sendable {
    var load = ""
    var repetitions = ""
    var duration = ""
    var distance = ""

    init() {}
    init(_ set: WorkoutSet, pounds: Bool, miles: Bool) {
        func text(_ value: Double?) -> String {
            value.map { $0.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...6))) } ?? ""
        }
        load = text(set.loadKg.map { $0 / (pounds ? 0.45359237 : 1) })
        repetitions = set.repetitions.map(String.init) ?? ""
        duration = text(set.durationSeconds)
        distance = text(set.distanceMeters.map { $0 / (miles ? 1609.344 : 1000) })
    }

    func applying(to original: WorkoutSet, measurement: ExerciseMeasurement, pounds: Bool, miles: Bool) throws -> WorkoutSet {
        var value = original
        switch measurement {
        case .externalLoad, .assistedLoad:
            value.loadKg = try TrainingTargetInput.decimal(load).map { $0 * (pounds ? 0.45359237 : 1) }
            value.repetitions = try TrainingTargetInput.integer(repetitions)
        case .bodyweight: value.repetitions = try TrainingTargetInput.integer(repetitions)
        case .duration, .cardio:
            // A running timer owns its elapsed value; completion samples it once.
            if value.timerStartedAt == nil {
                value.durationSeconds = try TrainingTargetInput.decimal(duration)
                value.accumulatedSeconds = value.durationSeconds ?? 0
            }
            if measurement == .cardio {
                value.distanceMeters = try TrainingTargetInput.decimal(distance).map { $0 * (miles ? 1609.344 : 1000) }
            }
        }
        try DomainValidation.number(value.loadKg, max: 5000)
        try DomainValidation.integer(value.repetitions)
        try DomainValidation.number(value.durationSeconds, max: 604800)
        try DomainValidation.number(value.distanceMeters, max: 10_000_000)
        return value
    }
}
