import Foundation

enum HealthSampleMapper {
    static func identifier(_ id: UUID, _ component: HealthComponent) -> String { "app.leanora.\(id.uuidString.lowercased()).\(component.rawValue)" }
    static func businessID(_ identifier: String, component: HealthComponent) -> UUID? {
        let prefix = "app.leanora.", suffix = ".\(component.rawValue)"
        guard identifier.hasPrefix(prefix), identifier.hasSuffix(suffix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(prefix.count).dropLast(suffix.count)))
    }
    static func export(_ record: BusinessRecord, component: HealthComponent, version: Int, source: String) throws -> HealthSampleValue? {
        guard record.stamp.deletedAt == nil else { return nil }
        var value: HealthSampleValue
        switch record {
        case .measurement(let m):
            guard component == (m.metric == .weightKg ? .weight : .bodyFat) else { return nil }
            value = HealthSampleValue(id: UUID(), source: source, component: component, start: m.occurred, end: m.occurred.instant,
                                      value: component == .bodyFat ? m.value / 100 : m.value)
        case .diet(let m):
            let number: Double?
            switch component {
            case .energy: number = m.nutrients.energyKcal
            case .protein: number = m.nutrients.proteinGrams
            case .carbohydrate: number = m.nutrients.carbohydrateGrams
            case .fat: number = m.nutrients.fatGrams
            default: return nil
            }
            guard let number else { return nil }
            value = HealthSampleValue(id: UUID(), source: source, component: component, start: m.occurred, end: m.occurred.instant, value: number)
        case .session(let m):
            guard component == .workout, m.status == .completed, let end = m.endedAt else { return nil }
            let strength = m.exercises.allSatisfy { [.externalLoad, .assistedLoad, .bodyweight].contains($0.snapshot.measurement) }
            let knownCardio: [UUID: String] = [20: "running", 21: "walking", 22: "cycling", 97: "elliptical", 98: "rowing", 99: "stairs", 100: "jumpRope"].reduce(into: [:]) { result, pair in
                result[UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", pair.key))!] = pair.value
            }
            let exerciseIDs = Set(m.exercises.map { $0.snapshot.exerciseID })
            let activity = strength ? "strength" : exerciseIDs.count == 1 ? knownCardio[exerciseIDs.first!] ?? "other" : "other"
            value = HealthSampleValue(id: UUID(), source: source, component: component, start: m.started, end: end, value: nil,
                                      activity: activity,
                                      duration: max(0, end.timeIntervalSince(m.started.instant) - m.pauses.reduce(0) { $0 + max(0, ($1.endedAt ?? end).timeIntervalSince($1.startedAt)) }), pauses: m.pauses)
        default: return nil
        }
        value.syncIdentifier = identifier(record.id, component); value.syncVersion = version
        return value
    }
    static func projection(_ sample: HealthSampleValue) throws -> HealthRuntimeRecord {
        switch sample.component {
        case .workout:
            return .workout(ExternalWorkout(sampleUUID: sample.id, sourceBundleID: sample.source, started: sample.start,
                                           endedAt: sample.end, activityType: sample.activity, energyKcal: sample.energyKcal, distanceMeters: sample.distanceMeters, durationSeconds: sample.duration))
        case .weight, .bodyFat:
            guard let value = sample.value else { throw DataProblem.invalid("健康测量值") }
            return .body(ExternalBodyMeasurement(sampleUUID: sample.id, sourceBundleID: sample.source, occurred: sample.start,
                                                metric: sample.component == .weight ? .weightKg : .bodyFatPercent,
                                                value: sample.component == .bodyFat ? value * 100 : value))
        default:
            guard let value = sample.value else { throw DataProblem.invalid("健康营养值") }
            return .nutrition(ExternalNutritionSample(sampleUUID: sample.id, sourceBundleID: sample.source, occurred: sample.start, component: sample.component, value: value))
        }
    }
}

enum HealthTransportProblem: Error, Sendable { case unavailable, writeDenied, timedOut, invalidSample, unconfirmedWrite }
protocol HealthTransport: Sendable {
    var sourceBundleID: String { get }
    func page(component: HealthComponent, cursor: HealthImportCursor, limit: Int) async throws -> HealthImportPage
    func activity(from: Date, to: Date, timeZoneID: String) async throws -> [HealthDailyActivity]
    func canWrite(_ component: HealthComponent) async -> Bool
    func findOwn(identifier: String, component: HealthComponent) async throws -> HealthSampleValue?
    func write(_ value: HealthSampleValue) async throws -> HealthSampleValue
    func deleteOwn(identifier: String, component: HealthComponent) async throws
    func deleteAllOwn() async throws
}
