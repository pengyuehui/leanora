import Foundation

// Domain values never escape as live SwiftData objects. Editing a catalog item
// therefore cannot mutate the snapshots inside an existing session or meal.
struct RecordStamp: Codable, Equatable, Sendable {
    var id = UUID()
    var revision = 1
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date?
}

struct RecordMoment: Codable, Equatable, Sendable {
    var instant: Date
    var timeZoneID: String
    var localDate: String

    init(_ instant: Date = Date(), timeZoneID: String = TimeZone.current.identifier) {
        self.instant = instant
        self.timeZoneID = timeZoneID
        localDate = Self.day(instant, timeZoneID: timeZoneID)
    }

    static func day(_ date: Date, timeZoneID: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

struct LocalProfile: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var weightUnit = "kg"
    var distanceUnit = "km"
    var timeZoneID = TimeZone.current.identifier
    var weeklyTrainingDays: Int?
}

struct ContentSource: Codable, Equatable, Sendable {
    var name = "用户创建"
    var license: String?
    var reference: String?
}

enum ExerciseMeasurement: String, Codable, Sendable {
    case externalLoad, bodyweight, assistedLoad, duration, cardio
}

struct Exercise: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var name: String
    var aliases: [String] = []
    var measurement: ExerciseMeasurement = .externalLoad
    var equipment: String = ""
    var muscles: [String] = []
    var source = ContentSource()
    var isArchived = false
}

struct ExerciseSnapshot: Codable, Equatable, Sendable {
    var exerciseID: UUID
    var revision: Int
    var name: String
    var measurement: ExerciseMeasurement

    init(_ exercise: Exercise) {
        exerciseID = exercise.stamp.id
        revision = exercise.stamp.revision
        name = exercise.name
        measurement = exercise.measurement
    }
}

struct TemplateItem: Codable, Equatable, Sendable {
    var id = UUID()
    var exerciseID: UUID
    var order: Int
    var plannedSets = 3
    var minimumReps: Int?
    var maximumReps: Int?
    var loadKg: Double?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var restSeconds: Double = 90
    var supersetID: UUID?
}

struct WorkoutTemplate: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var name: String
    var items: [TemplateItem] = []
    // ISO weekdays: Monday = 1, Sunday = 7.
    var scheduledWeekdays: [Int] = []
    var notes = ""
}

enum EffortScale: String, Codable, Sendable { case rpe, rir }
struct EffortValue: Codable, Equatable, Sendable {
    var scale: EffortScale
    var value: Double
}
enum WorkoutSetKind: String, Codable, Sendable { case working, warmup, drop, failure }
struct WorkoutSet: Codable, Equatable, Sendable {
    var id = UUID()
    var order: Int
    var kind: WorkoutSetKind = .working
    var loadKg: Double?
    var repetitions: Int?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var effort: EffortValue?
    var completedAt: Date?
    var timerStartedAt: Date?
    var accumulatedSeconds: Double = 0
}
struct SessionExercise: Codable, Equatable, Sendable {
    var id = UUID()
    var order: Int
    var snapshot: ExerciseSnapshot
    var sets: [WorkoutSet] = []
    var supersetID: UUID?
    var notes = ""
    var templateItemID: UUID?
    var plannedTargets: PlannedTargets?
}
struct PauseInterval: Codable, Equatable, Sendable {
    var startedAt: Date
    var endedAt: Date?
}
enum WorkoutStatus: String, Codable, Sendable { case draft, active, paused, completed, abandoned }
struct WorkoutSession: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var started = RecordMoment()
    var endedAt: Date?
    var status: WorkoutStatus = .draft
    var templateID: UUID?
    var templateRevision: Int?
    var name: String
    var exercises: [SessionExercise] = []
    var pauses: [PauseInterval] = []
    var restDeadline: Date?
    var notes = ""
    var scheduleOriginDate: String?
}

// Optional additive fields retain compatibility with U2 JSON payloads.
struct PlannedTargets: Codable, Equatable, Sendable {
    var sets: Int
    var minimumReps: Int?
    var maximumReps: Int?
    var loadKg: Double?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var restSeconds: Double
}

struct WorkoutDayChange: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var templateID: UUID
    var originDate: String
    var destinationDate: String
    var timeZoneID: String
}
