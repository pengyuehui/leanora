import Foundation

enum HealthComponent: String, Codable, CaseIterable, Sendable {
    case workout, weight, bodyFat, energy, protein, carbohydrate, fat
}
enum HealthJobAction: String, Codable, Sendable { case write, delete }
enum HealthLinkState: String, Codable, Sendable { case pendingWrite, written, pendingDelete, deleted, failed }
struct HealthWriteJob: Codable, Equatable, Sendable {
    var businessID: UUID
    var desiredRevision: Int
    var component: HealthComponent
    var action: HealthJobAction
    var attempts = 0
    var errorCategory: String?
    var syncVersion: Int?
    var userInitiated: Bool?
    var key: String { "job:\(businessID):\(component.rawValue)" }
}
struct HealthSampleLink: Codable, Equatable, Sendable {
    var businessID: UUID
    var component: HealthComponent
    var sampleUUID: UUID
    var syncIdentifier: String
    var version: Int
    var sourceBundleID: String
    var state: HealthLinkState
}
struct HealthImportCursor: Codable, Equatable, Sendable {
    var installationID: UUID
    var sampleType: String
    var anchor: Data?
    var queryStart: Date
    var queryEnd: Date?
    var key: String { "cursor:\(installationID):\(sampleType)" }
}
struct HealthSuppression: Codable, Equatable, Sendable {
    var sampleUUID: UUID
    var businessID: UUID?
    var component: HealthComponent
    var reason: String
}
struct ExternalWorkout: Codable, Equatable, Sendable {
    var sampleUUID: UUID
    var sourceBundleID: String
    var started: RecordMoment
    var endedAt: Date
    var activityType: String
    var energyKcal: Double?
    var distanceMeters: Double?
    var durationSeconds: Double?
}
struct ExternalNutritionSample: Codable, Equatable, Sendable {
    var sampleUUID: UUID
    var sourceBundleID: String
    var occurred: RecordMoment
    var component: HealthComponent
    var value: Double
}
struct ExternalBodyMeasurement: Codable, Equatable, Sendable {
    var sampleUUID: UUID
    var sourceBundleID: String
    var occurred: RecordMoment
    var metric: BodyMetric
    var value: Double
}

// These values are installation-local and are deliberately absent from backups.
enum HealthRuntimeRecord: Codable, Equatable, Sendable {
    case job(HealthWriteJob), link(HealthSampleLink), cursor(HealthImportCursor)
    case suppression(HealthSuppression), workout(ExternalWorkout)
    case nutrition(ExternalNutritionSample), body(ExternalBodyMeasurement)
    case reconciliationRequired(Bool)
    case configuration(HealthSyncConfiguration), check(HealthCheck)
    case activity(HealthDailyActivity), hold(UUID), floor(HealthVersionFloor)
    case association(HealthWorkoutAssociation)
    case currentLink(HealthSampleLink), componentSuppression(HealthSuppression)

    var key: String {
        switch self {
        case .job(let v): v.key
        case .link(let v): "link:\(v.sampleUUID)"
        case .cursor(let v): v.key
        case .suppression(let v): "suppression:\(v.sampleUUID)"
        case .workout(let v): "external:\(v.sampleUUID)"
        case .nutrition(let v): "external:\(v.sampleUUID)"
        case .body(let v): "external:\(v.sampleUUID)"
        case .reconciliationRequired: "health:reconciliation"
        case .configuration: "health:configuration"
        case .check: "health:check"
        case .activity(let v): "activity:\(v.timeZoneID):\(v.day)"
        case .hold(let id): "hold:\(id)"
        case .floor(let v): "floor:\(v.identifier)"
        case .association(let v): "association:\(v.sampleUUID)"
        case .currentLink(let v): "current:\(v.businessID):\(v.component.rawValue)"
        case .componentSuppression(let v): "blocked:\(v.businessID?.uuidString ?? "invalid"):\(v.component.rawValue)"
        }
    }
}

struct HealthSyncConfiguration: Codable, Equatable, Sendable {
    var enabled = false
    var reading: Set<HealthComponent> = [.weight, .workout]
    var writing: Set<HealthComponent> = []
    var readActivity = false
    var generation = UUID()
    var queryStart = Date().addingTimeInterval(-90 * 86_400)
}
struct HealthCheck: Codable, Equatable, Sendable {
    var attemptedAt = Date()
    var succeededAt: Date?
    var retryNeeded = false
    var message: String?
}
struct HealthDailyActivity: Codable, Equatable, Sendable {
    var day: String
    var timeZoneID: String
    var steps: Double?
    var activeEnergyKcal: Double?
}
struct HealthVersionFloor: Codable, Equatable, Sendable {
    var identifier: String
    var version: Int
}

struct HealthSampleValue: Equatable, Sendable {
    var id: UUID
    var source: String
    var component: HealthComponent
    var start: RecordMoment
    var end: Date
    var value: Double?
    var activity: String = "other"
    var duration: Double?
    var energyKcal: Double?
    var distanceMeters: Double?
    var syncIdentifier: String?
    var syncVersion: Int?
    var pauses: [PauseInterval] = []
}

enum HealthWorkoutPrimary: String, Codable, CaseIterable, Sendable { case local, health }
struct HealthWorkoutAssociation: Codable, Equatable, Sendable {
    var sampleUUID: UUID
    var businessID: UUID
    var primary: HealthWorkoutPrimary
}
struct HealthImportPage: Sendable {
    var samples: [HealthSampleValue]
    var deleted: [UUID]
    var anchor: Data
    var hasMore: Bool
}

extension HealthComponent {
    var title: String {
        switch self {
        case .workout: "训练"
        case .weight: "体重"
        case .bodyFat: "体脂率"
        case .energy: "热量"
        case .protein: "蛋白质"
        case .carbohydrate: "碳水"
        case .fat: "脂肪"
        }
    }
}
