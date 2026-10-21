import Foundation
@testable import Leanora

actor HealthTestTransport: HealthTransport {
    nonisolated let sourceBundleID = "app.leanora.dev"
    var values: [UUID: HealthSampleValue] = [:]
    var events: [(HealthComponent, HealthSampleValue?, UUID)] = []
    var allowed = Set(HealthComponent.allCases)
    var failAtOffset: Int?
    var failConfirmation: AppModelActor?
    var writes = 0
    var pages = 0
    private var shouldBlock = false
    private var blocked = false
    private var release: CheckedContinuation<Void, Never>?
    private var entered: [CheckedContinuation<Void, Never>] = []
    func blockNextWrite() { shouldBlock = true }
    func waitForBlockedWrite() async {
        if blocked { return }
        await withCheckedContinuation { entered.append($0) }
    }
    func releaseWrite() { release?.resume(); release = nil }
    func allow(_ components: Set<HealthComponent>) { allowed = components }
    func failPage(_ offset: Int?) { failAtOffset = offset }
    func failNextConfirmation(_ repository: AppModelActor) { failConfirmation = repository }
    func seed(_ samples: [HealthSampleValue]) {
        for sample in samples { values[sample.id] = sample; events.append((sample.component, sample, sample.id)) }
    }
    func remove(_ id: UUID) {
        guard let old = values.removeValue(forKey: id) else { return }; events.append((old.component, nil, id))
    }
    func all() -> [HealthSampleValue] { Array(values.values) }
    func counts() -> (writes: Int, pages: Int) { (writes, pages) }
    func page(component: HealthComponent, cursor: HealthImportCursor, limit: Int) async throws -> HealthImportPage {
        pages += 1
        let offset = cursor.anchor.flatMap { Int(String(decoding: $0, as: UTF8.self)) } ?? 0
        if failAtOffset == offset { failAtOffset = nil; throw CocoaError(.fileReadNoPermission) }
        let matching = events.filter { $0.0 == component }
        let batch = matching.dropFirst(offset).prefix(limit)
        return HealthImportPage(samples: batch.compactMap(\.1).filter { $0.start.instant >= cursor.queryStart }, deleted: batch.filter { $0.1 == nil }.map(\.2),
                                anchor: Data(String(offset + batch.count).utf8), hasMore: offset + batch.count < matching.count)
    }
    func activity(from: Date, to: Date, timeZoneID: String) async throws -> [HealthDailyActivity] {
        [HealthDailyActivity(day: RecordMoment.day(to, timeZoneID: timeZoneID), timeZoneID: timeZoneID, steps: 123, activeEnergyKcal: 45)]
    }
    func canWrite(_ component: HealthComponent) async -> Bool { allowed.contains(component) }
    func findOwn(identifier: String, component: HealthComponent) async throws -> HealthSampleValue? {
        values.values.filter { $0.source == sourceBundleID && $0.syncIdentifier == identifier && $0.component == component }.max { ($0.syncVersion ?? 0) < ($1.syncVersion ?? 0) }
    }
    func write(_ value: HealthSampleValue) async throws -> HealthSampleValue {
        if shouldBlock {
            shouldBlock = false; blocked = true
            let waiters = entered; entered = []; for waiter in waiters { waiter.resume() }
            await withCheckedContinuation { release = $0 }; blocked = false
        }
        if let old = try await findOwn(identifier: value.syncIdentifier!, component: value.component) {
            if old.syncVersion! >= value.syncVersion! { return old }; remove(old.id)
        }
        writes += 1; seed([value])
        if let repository = failConfirmation { failConfirmation = nil; await repository.injectCommitFailure() }
        return value
    }
    func deleteOwn(identifier: String, component: HealthComponent) async throws {
        for value in values.values.filter({ $0.source == sourceBundleID && $0.syncIdentifier == identifier && $0.component == component }) { remove(value.id) }
    }
    func deleteAllOwn() async throws { for value in values.values.filter({ $0.source == sourceBundleID }) { remove(value.id) } }
}

enum HealthFixtures {
    static func repository(reading: Set<HealthComponent> = [], writing: Set<HealthComponent> = Set(HealthComponent.allCases)) async throws -> AppModelActor {
        let repository = AppModelActor(modelContainer: try StoreFactory.memory()); try await repository.initializeProfile()
        try await repository.configureHealth(HealthSyncConfiguration(enabled: true, reading: reading, writing: writing))
        return repository
    }
    static func sample(_ component: HealthComponent = .weight, source: String = "watch.example", value: Double = 65) -> HealthSampleValue {
        HealthSampleValue(id: UUID(), source: source, component: component, start: RecordMoment(), end: Date(), value: value)
    }
}
