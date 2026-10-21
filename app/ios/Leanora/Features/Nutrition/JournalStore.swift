import Foundation
import Observation

extension Food: Identifiable { var id: UUID { stamp.id } }
extension DietEntry: Identifiable { var id: UUID { stamp.id } }
extension BodyMeasurement: Identifiable { var id: UUID { stamp.id } }

@MainActor @Observable final class JournalStore {
    let repository: AppModelActor
    let catalog: [Food]
    private(set) var foods: [Food] = []
    private(set) var entries: [DietEntry] = []
    private(set) var measurements: [BodyMeasurement] = []
    private(set) var goals: [NutritionGoal] = []
    private(set) var busy = false
    private(set) var dataVersion = 0
    var error: String?
    private var generation = 0
    init(repository: AppModelActor, catalog: [Food]) { self.repository = repository; self.catalog = catalog }
    func refresh() async {
        generation += 1; let current = generation
        do {
            let records = try await repository.snapshot()
            guard current == generation else { return }
            var available = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
            for record in records { if case .food(let food) = record { available[food.stamp.id] = food } }
            let newFoods = available.values.filter { $0.stamp.deletedAt == nil }.sorted { $0.name < $1.name }
            let newEntries = records.compactMap { if case .diet(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }
            let newMeasurements = records.compactMap { if case .measurement(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }
            let newGoals = records.compactMap { if case .goal(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }
            if foods != newFoods || entries != newEntries || measurements != newMeasurements || goals != newGoals { dataVersion += 1 }
            foods = newFoods; entries = newEntries; measurements = newMeasurements; goals = newGoals
        } catch { self.error = error.localizedDescription }
    }
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> T? {
        guard !busy else { return nil }; busy = true; error = nil; defer { busy = false }
        do { let result = try await operation(); await refresh(); return result }
        catch { self.error = error.localizedDescription; return nil }
    }
}
