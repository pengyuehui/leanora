import XCTest
@testable import Leanora

final class FoodCatalogTests: XCTestCase {
    func testChineseAndEnglishDiscoveryRetainsCookingStatesAndSources() throws {
        let foods = try FoodCatalog.load()
        XCTAssertEqual(foods.count, 500)
        XCTAssertGreaterThanOrEqual(foods.filter { $0.name.range(of: "\\p{Han}", options: .regularExpression) != nil }.count, 150)
        XCTAssertEqual(Set(foods.map { $0.stamp.id }).count, 500)
        XCTAssertTrue(FoodCatalog.search(foods, query: "糙米 熟").allSatisfy { $0.name.contains("熟") })
        XCTAssertFalse(FoodCatalog.search(foods, query: "糙米 熟").isEmpty)
        XCTAssertFalse(FoodCatalog.search(foods, query: "白米饭").isEmpty)
        XCTAssertFalse(FoodCatalog.search(foods, query: "RICE cooked").isEmpty)
        XCTAssertTrue(foods.allSatisfy { $0.category != nil && $0.source.license == "CC0-1.0" })
    }

    func testCatalogDiscoveryUpgradePreservesLocalStateNutritionAndHistory() throws {
        let current = try XCTUnwrap(FoodCatalog.search(FoodCatalog.load(), query: "白米饭").first)
        var stored = current; stored.name = "Rice legacy label"; stored.aliases = []
        stored.isFavorite = true; stored.isArchived = true; stored.stamp.revision = 8
        let snapshot = FoodSnapshot(stored)
        let result = try XCTUnwrap(NutritionWorkflow.foods(catalog: [current], records: [stored]).first)
        XCTAssertEqual(result.name, current.name); XCTAssertTrue(result.aliases.contains("Rice legacy label"))
        XCTAssertEqual(result.stamp, stored.stamp); XCTAssertEqual(result.isFavorite, true); XCTAssertTrue(result.isArchived)
        XCTAssertEqual(result.units, stored.units); XCTAssertEqual(result.nutrientsPer100Grams, stored.nutrientsPer100Grams)
        XCTAssertEqual(snapshot.name, "Rice legacy label")
    }

    func testMissingOptionalFoodFieldsInOldJSONDecode() throws {
        let food = Food(name: "旧食品", nutrientsPer100Grams: Nutrients(energyKcal: 50))
        let restored = try RecordCoding.decode(Food.self, from: RecordCoding.encode(food))
        XCTAssertNil(restored.isFavorite); XCTAssertNil(restored.category)
        XCTAssertEqual(try RecordCoding.encode(restored), try RecordCoding.encode(food))
    }
}
