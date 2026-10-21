import XCTest
@testable import Leanora

final class DietDiaryTests: XCTestCase, @unchecked Sendable {
    private func fixture() async throws -> (AppModelActor, Food, DietEntry) {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile(); try await actor.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.energy, .protein]))
        let food = Food(name: "原名", nutrientsPer100Grams: Nutrients(energyKcal: 100, proteinGrams: 5))
        try await actor.saveCustomFood(food, catalog: [])
        let entry = try NutritionCalculator.entry(food: food, quantity: 150, unit: nil, meal: .breakfast, at: Date())
        try await actor.saveDiet(entry, catalog: []); return (actor, food, entry)
    }
    func testFoodRevisionDoesNotRewriteHistoricalDietSnapshot() async throws {
        let (actor, food, entry) = try await fixture(); var edited = food
        edited.name = "改名"; edited.nutrientsPer100Grams.energyKcal = 500
        try await actor.saveCustomFood(edited, catalog: [])
        let records = try await actor.snapshot()
        guard case .diet(let stored) = records.first(where: { $0.id == entry.stamp.id }) else { return XCTFail() }
        XCTAssertEqual(stored.food?.name, "原名"); XCTAssertEqual(stored.nutrients.energyKcal, 150)
    }
    func testMealCopiesHaveNewIDsAndIndependentSnapshots() async throws {
        let (actor, _, entry) = try await fixture()
        let count = try await actor.copyMeal(from: entry.occurred.localDate, meal: .breakfast, to: Date().addingTimeInterval(86400), destinationMeal: .lunch)
        XCTAssertEqual(count, 1)
        let records = try await actor.snapshot(); let entries = records.compactMap { if case .diet(let v) = $0 { return v }; return nil }
        XCTAssertEqual(Set(entries.map { $0.stamp.id }).count, 2)
        let copy = entries.first { $0.stamp.id != entry.stamp.id }!
        XCTAssertEqual(copy.food, entry.food); XCTAssertEqual(copy.nutrients, entry.nutrients); XCTAssertEqual(copy.meal, .lunch)
    }
    func testDietAndHealthIntentsRollbackTogether() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile(); try await actor.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.energy, .protein]))
        let entry = DietEntry(meal: .snack, nutrients: Nutrients(energyKcal: 100))
        await actor.injectCommitFailure()
        do { try await actor.saveDiet(entry, catalog: []); XCTFail() } catch {}
        let records = try await actor.snapshot(); XCTAssertFalse(records.contains { $0.id == entry.stamp.id })
        let runtime = try await actor.runtimeSnapshot(); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
        try await actor.saveDiet(entry, catalog: [])
        let saved = try await actor.runtimeSnapshot(); XCTAssertEqual(saved.filter { if case .job = $0 { return true }; return false }.count, 1)
    }
    func testKnownNutrientRemovedQueuesDeletionOfExistingComponent() async throws {
        let (actor, _, original) = try await fixture()
        try await actor.saveHealthMetadata(links: [HealthSampleLink(businessID: original.stamp.id, component: .protein, sampleUUID: UUID(), syncIdentifier: "test", version: 1, sourceBundleID: "app.leanora.dev", state: .written)])
        var changed = original; changed.food = nil; changed.grams = nil; changed.nutrients = Nutrients(energyKcal: 100)
        try await actor.saveDiet(changed, catalog: [])
        let jobs = try await actor.runtimeSnapshot().compactMap { if case .job(let j) = $0 { return j }; return nil }
        XCTAssertTrue(jobs.contains { $0.component == .protein && $0.action == .delete && $0.desiredRevision == 2 })
    }
    func testDeleteTombstoneAndJobsUseLatestRevision() async throws {
        let (actor, _, entry) = try await fixture()
        try await actor.deleteDiet(entry.stamp.id, revision: 1, deleteHealthCopies: true)
        let records = try await actor.snapshot()
        guard case .diet(let deleted) = records.first(where: { $0.id == entry.stamp.id }) else { return XCTFail() }
        XCTAssertNotNil(deleted.stamp.deletedAt); XCTAssertEqual(deleted.stamp.revision, 2)
        let jobs = try await actor.runtimeSnapshot().compactMap { if case .job(let j) = $0 { return j }; return nil }
        XCTAssertTrue(jobs.allSatisfy { $0.action == .delete && $0.desiredRevision == 2 })
    }
}
