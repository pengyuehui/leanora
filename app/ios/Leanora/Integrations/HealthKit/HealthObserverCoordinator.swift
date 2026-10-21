#if os(iOS)
import Foundation
@preconcurrency import HealthKit

@MainActor final class HealthObserverCoordinator {
    private let store = HKHealthStore()
    private var queries: [HKObserverQuery] = []
    private var observed: Set<HKSampleType> = []
    func start(configuration: HealthSyncConfiguration, engine: HealthSyncEngine, didChange: @escaping @MainActor @Sendable () async -> Void) {
        var desired = configuration.enabled ? Set(configuration.reading.map(SystemHealthTransport.type)) : []
        if configuration.enabled && configuration.readActivity { desired.formUnion([HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]) }
        guard observed != desired else { return }
        stop(); observed = desired
        for type in desired {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                // The engine saves retryNeeded before querying. Completion is
                // called exactly once even for a locked store or failed page.
                let finished = HealthObserverCompletion(completion)
                Task { await engine.run(); await didChange(); finished.finish() }
            }
            queries.append(query); store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }
    func stop() {
        for query in queries { store.stop(query) }
        for type in observed { store.disableBackgroundDelivery(for: type) { _, _ in } }
        queries = []; observed = []
    }
}
private final class HealthObserverCompletion: @unchecked Sendable {
    private let completion: () -> Void
    init(_ completion: @escaping () -> Void) { self.completion = completion }
    func finish() { completion() }
}
#endif
