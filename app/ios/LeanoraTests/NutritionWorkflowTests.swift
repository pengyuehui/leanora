import XCTest
@testable import Leanora

final class NutritionWorkflowTests: XCTestCase, @unchecked Sendable {
    func testRecentFiltersDeletedArchivedAndComposesSearchAndCategory() throws {
        var a = Food(name: "米饭", nutrientsPer100Grams: Nutrients(energyKcal: 130), isFavorite: true, category: "谷物与主食")
        let b = Food(name: "鸡蛋", nutrientsPer100Grams: Nutrients(energyKcal: 140), category: "奶与蛋")
        let time = DataFixtures.date
        let first = try NutritionCalculator.entry(food: a, quantity: 150, unit: nil, meal: .lunch, at: time)
        var removed = try NutritionCalculator.entry(food: b, quantity: 50, unit: nil, meal: .lunch, at: time.addingTimeInterval(10))
        removed.stamp.deletedAt = Date()
        XCTAssertEqual(NutritionWorkflow.recentFoodIDs([first, first, removed]), [a.stamp.id])
        XCTAssertEqual(NutritionWorkflow.previousGrams(foodID: a.stamp.id, entries: [first]), 150)
        XCTAssertEqual(NutritionWorkflow.search([a,b], catalog: [a,b], entries: [first], query: "米", filter: .favorites, category: "谷物与主食").map(\.name), ["米饭"])
        XCTAssertTrue(NutritionWorkflow.search([a,b], catalog: [a,b], entries: [first], query: "", filter: .recent, category: "奶与蛋").isEmpty)
        a.isArchived = true
        XCTAssertTrue(NutritionWorkflow.search([a,b], catalog: [a,b], entries: [first], query: "", filter: .recent, category: nil).isEmpty)
    }

    func testFoodFavoritesAreIdempotentPersistedBackedUpAndNotHealthWrites() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let food = Food(name: "目录食品", nutrientsPer100Grams: Nutrients(energyKcal: 100))
        try await actor.setFoodFavorite(food.stamp.id, favorite: true, catalog: [food])
        try await actor.setFoodFavorite(food.stamp.id, favorite: true, catalog: [food])
        let records = try await actor.snapshot()
        guard case .food(let saved) = records.first(where: { $0.id == food.stamp.id }) else { return XCTFail() }
        XCTAssertEqual(saved.isFavorite, true); XCTAssertEqual(saved.stamp.revision, 1)
        let exported = try await actor.exportBackup(); let document = try BackupService.decode(exported.data)
        XCTAssertTrue(document.records.contains(.food(saved)))
        let runtime = try await actor.runtimeSnapshot(); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
        await actor.injectCommitFailure()
        do { try await actor.setFoodFavorite(food.stamp.id, favorite: false, catalog: [food]); XCTFail() } catch {}
        let after = try await actor.snapshot(); XCTAssertTrue(after.contains(.food(saved)))
    }
}
