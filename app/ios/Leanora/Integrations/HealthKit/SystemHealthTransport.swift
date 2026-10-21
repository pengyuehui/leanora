#if os(iOS)
import Foundation
@preconcurrency import HealthKit

// HKHealthStore queries are thread-safe; no SwiftData objects cross callbacks.
final class SystemHealthTransport: HealthTransport, @unchecked Sendable {
    let store = HKHealthStore()
    let sourceBundleID = Bundle.main.bundleIdentifier ?? "ai.leanora.fitness"

    static func type(_ component: HealthComponent) -> HKSampleType {
        switch component {
        case .workout: HKObjectType.workoutType()
        case .weight: HKQuantityType(.bodyMass)
        case .bodyFat: HKQuantityType(.bodyFatPercentage)
        case .energy: HKQuantityType(.dietaryEnergyConsumed)
        case .protein: HKQuantityType(.dietaryProtein)
        case .carbohydrate: HKQuantityType(.dietaryCarbohydrates)
        case .fat: HKQuantityType(.dietaryFatTotal)
        }
    }
    static func unit(_ component: HealthComponent) -> HKUnit {
        switch component {
        case .weight: .gramUnit(with: .kilo)
        case .bodyFat: .percent()
        case .energy: .kilocalorie()
        default: .gram()
        }
    }
    static func mapped(_ sample: HKSample, component: HealthComponent) -> HealthSampleValue {
        let metadata = sample.metadata ?? [:]
        let zone = metadata[HKMetadataKeyTimeZone] as? String ?? TimeZone.current.identifier
        var result = HealthSampleValue(id: sample.uuid, source: sample.sourceRevision.source.bundleIdentifier, component: component,
                                       start: RecordMoment(sample.startDate, timeZoneID: zone), end: sample.endDate,
                                       value: (sample as? HKQuantitySample)?.quantity.doubleValue(for: unit(component)),
                                       syncIdentifier: metadata[HKMetadataKeySyncIdentifier] as? String,
                                       syncVersion: (metadata[HKMetadataKeySyncVersion] as? NSNumber)?.intValue)
        if let workout = sample as? HKWorkout {
            result.duration = workout.duration
            result.activity = workout.workoutActivityType == .traditionalStrengthTraining ? "strength" : "运动类型 \(workout.workoutActivityType.rawValue)"
            result.energyKcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let distanceType: HKQuantityTypeIdentifier? = switch workout.workoutActivityType {
            case .running, .walking: .distanceWalkingRunning
            case .cycling: .distanceCycling
            case .swimming: .distanceSwimming
            default: nil
            }
            if let distanceType { result.distanceMeters = workout.statistics(for: HKQuantityType(distanceType))?.sumQuantity()?.doubleValue(for: .meter()) }
        }
        return result
    }
    func page(component: HealthComponent, cursor: HealthImportCursor, limit: Int) async throws -> HealthImportPage {
        let anchor = try cursor.anchor.flatMap { try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        return try await withCheckedThrowingContinuation { continuation in
            let reply = HealthQueryReply(continuation)
            let predicate = HKQuery.predicateForSamples(withStart: cursor.queryStart, end: cursor.queryEnd, options: .strictStartDate)
            let query = HKAnchoredObjectQuery(type: Self.type(component), predicate: predicate, anchor: anchor, limit: limit) { _, samples, deleted, anchor, error in
                if let error { reply.finish(.failure(error)); return }
                do {
                    guard let samples, let deleted, let anchor else { throw HealthTransportProblem.invalidSample }
                    let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                    reply.finish(.success(HealthImportPage(samples: samples.map { Self.mapped($0, component: component) }, deleted: deleted.map(\.uuid),
                                                           anchor: data, hasMore: samples.count + deleted.count >= limit)))
                } catch { reply.finish(.failure(error)) }
            }
            execute(query, reply: reply)
        }
    }
    func activity(from: Date, to: Date, timeZoneID: String) async throws -> [HealthDailyActivity] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        let start = calendar.startOfDay(for: from)
        var interval = DateComponents(); interval.day = 1; interval.calendar = calendar; interval.timeZone = calendar.timeZone
        let steps = try await statistics(type: HKQuantityType(.stepCount), unit: .count(), start: start, end: to, interval: interval)
        let energy = try await statistics(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), start: start, end: to, interval: interval)
        var day = start, values: [HealthDailyActivity] = []
        while day <= to {
            values.append(HealthDailyActivity(day: RecordMoment.day(day, timeZoneID: timeZoneID), timeZoneID: timeZoneID,
                                             steps: steps[day], activeEnergyKcal: energy[day]))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return values
    }
    private func statistics(type: HKQuantityType, unit: HKUnit, start: Date, end: Date, interval: DateComponents) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let reply = HealthQueryReply(continuation)
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                                                     options: .cumulativeSum, anchorDate: start, intervalComponents: interval)
            query.initialResultsHandler = { [store] query, collection, error in
                defer { store.stop(query) }
                if let error { reply.finish(.failure(error)); return }
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() { values[stats.startDate] = sum.doubleValue(for: unit) }
                }
                reply.finish(.success(values))
            }
            execute(query, reply: reply)
        }
    }
    func canWrite(_ component: HealthComponent) async -> Bool { store.authorizationStatus(for: Self.type(component)) == .sharingAuthorized }
    private func ownPredicate(_ identifier: String? = nil) -> NSPredicate {
        let source = HKQuery.predicateForObjects(from: HKSource.default())
        guard let identifier else { return source }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [source, HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [identifier])])
    }
    func findOwn(identifier: String, component: HealthComponent) async throws -> HealthSampleValue? {
        try await withCheckedThrowingContinuation { continuation in
            let reply = HealthQueryReply(continuation)
            let query = HKSampleQuery(sampleType: Self.type(component), predicate: ownPredicate(identifier), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { reply.finish(.failure(error)); return }
                let mapped = (samples ?? []).map { Self.mapped($0, component: component) }
                reply.finish(.success(mapped.max { ($0.syncVersion ?? 0) < ($1.syncVersion ?? 0) }))
            }
            execute(query, reply: reply)
        }
    }
    func write(_ value: HealthSampleValue) async throws -> HealthSampleValue {
        guard let identifier = value.syncIdentifier, let version = value.syncVersion, await canWrite(value.component) else { throw HealthTransportProblem.writeDenied }
        let metadata: [String: Any] = [HKMetadataKeySyncIdentifier: identifier, HKMetadataKeySyncVersion: NSNumber(value: version), HKMetadataKeyTimeZone: value.start.timeZoneID]
        let sample: HKSample
        if value.component == .workout {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = switch value.activity {
            case "strength": .traditionalStrengthTraining
            case "running": .running
            case "walking": .walking
            case "cycling": .cycling
            case "rowing": .rowing
            case "elliptical": .elliptical
            case "stairs": .stairClimbing
            case "jumpRope": .jumpRope
            default: .other
            }
            let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
            try await builder.beginCollection(at: value.start.instant)
            try await builder.addMetadata(metadata)
            var events: [HKWorkoutEvent] = []
            for pause in value.pauses {
                events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.startedAt, duration: 0), metadata: nil))
                if let end = pause.endedAt { events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: end, duration: 0), metadata: nil)) }
            }
            if !events.isEmpty { try await builder.addWorkoutEvents(events) }
            try await builder.endCollection(at: value.end)
            guard let workout = try await builder.finishWorkout() else { throw HealthTransportProblem.invalidSample }
            sample = workout
        } else {
            guard let number = value.value, let type = Self.type(value.component) as? HKQuantityType else { throw HealthTransportProblem.invalidSample }
            sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: Self.unit(value.component), doubleValue: number), start: value.start.instant, end: value.end, metadata: metadata)
            try await store.save(sample)
        }
        // Saving an equal version may retain Health's previous UUID.
        guard let confirmed = try await findOwn(identifier: identifier, component: value.component), (confirmed.syncVersion ?? 0) >= version else {
            // A save may retain an existing version/UUID. A tentative object's
            // UUID is not proof of a confirmed Health sample after a restore.
            throw HealthTransportProblem.unconfirmedWrite
        }
        return confirmed
    }
    func deleteOwn(identifier: String, component: HealthComponent) async throws {
        _ = try await store.deleteObjects(of: Self.type(component), predicate: ownPredicate(identifier))
    }
    func deleteAllOwn() async throws {
        var failure: (any Error)?
        for component in HealthComponent.allCases {
            do { _ = try await store.deleteObjects(of: Self.type(component), predicate: ownPredicate()) }
            catch { failure = error }
        }
        if let failure { throw failure }
    }
    private func execute<T>(_ query: HKQuery, reply: HealthQueryReply<T>) {
        store.execute(query)
        // Locked/unavailable queries cannot retain an observer completion forever.
        DispatchQueue.global().asyncAfter(deadline: .now() + 25) { [store] in
            if reply.finish(.failure(HealthTransportProblem.timedOut)) { store.stop(query) }
        }
    }
}

private final class HealthQueryReply<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    init(_ continuation: CheckedContinuation<Value, any Error>) { self.continuation = continuation }
    @discardableResult func finish(_ result: Result<Value, any Error>) -> Bool {
        lock.lock(); let pending = continuation; continuation = nil; lock.unlock()
        pending?.resume(with: result)
        return pending != nil
    }
}
#endif
