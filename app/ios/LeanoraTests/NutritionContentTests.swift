import XCTest
@testable import Leanora

final class NutritionContentTests: XCTestCase, @unchecked Sendable {
    func testBundledExamplesAndGuidesResolveAndCalculateFromFoodSnapshots() throws {
        let catalog = try NutritionContentCatalog.load(), foods = try FoodCatalog.load()
        XCTAssertEqual(catalog.recipes.count, 6); XCTAssertEqual(catalog.guides.count, 8)
        XCTAssertEqual(catalog.license, "MIT"); XCTAssertEqual(catalog.author, "Leanora")
        for recipe in catalog.recipes {
            let draft = try catalog.draft(recipeID: recipe.id, foods: foods)
            XCTAssertEqual(draft.items.count, recipe.items.count)
            let entries = try draft.entries(servings: 1, meal: .lunch, date: DataFixtures.date)
            for (entry, item) in zip(entries, recipe.items) {
                let food = try XCTUnwrap(foods.first { $0.stamp.id == item.foodID })
                XCTAssertEqual(entry.nutrients, food.nutrientsPer100Grams.scaled(by: item.grams / 100))
                XCTAssertEqual(entry.food?.source.license, "CC0-1.0")
            }
        }
    }
    func testPreviewDraftDoesNotWriteUntilExplicitlySaved() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let before = try await actor.exportBackup()
        let catalog = try NutritionContentCatalog.load(), foods = try FoodCatalog.load()
        let draft = try catalog.draft(recipeID: catalog.recipes[0].id, foods: foods)
        let after = try await actor.exportBackup(); XCTAssertEqual(before.fingerprint, after.fingerprint)
        _ = try await actor.saveMealTemplate(draft, catalog: foods)
        let records = try await actor.snapshot(); XCTAssertEqual(records.filter { $0.kind == "mealTemplate" }.count, 1)
        XCTAssertFalse(records.contains { $0.kind == "diet" })
    }
    func testCorruptMissingReferencesAndUnknownVersionsFailClosed() throws {
        let invalid = Data("{}".utf8)
        XCTAssertThrowsError(try NutritionContentCatalog.decode(invalid, foods: []))
        var document = try NutritionContentCatalog.load()
        document.recipes[0].items[0].foodID = UUID()
        XCTAssertThrowsError(try document.draft(recipeID: document.recipes[0].id, foods: FoodCatalog.load()))
        let fields: [String: Any] = ["version":999,"author":"Leanora","license":"MIT","recipes":[],"guides":[]]
        XCTAssertThrowsError(try NutritionContentCatalog.decode(JSONSerialization.data(withJSONObject: fields), foods: []))
    }
}
