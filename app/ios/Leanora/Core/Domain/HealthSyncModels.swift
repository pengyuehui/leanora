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
        }
    }
}
