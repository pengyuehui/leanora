import XCTest
@testable import Leanora

final class NutritionCalculationTests: XCTestCase {
    func testHundredToHundredFiftyGramsScalesAllKnownValues() throws {
        let food = Food(name: "测试", nutrientsPer100Grams: Nutrients(energyKcal: 100, proteinGrams: 10, carbohydrateGrams: 20, fatGrams: 5))
        let entry = try NutritionCalculator.entry(food: food, quantity: 150, unit: nil, meal: .lunch, at: Date())
        XCTAssertEqual(entry.nutrients, Nutrients(energyKcal: 150, proteinGrams: 15, carbohydrateGrams: 30, fatGrams: 7.5))
    }
    func testServingConversionAndKilojoules() throws {
        let unit = FoodUnit(name: "袋", grams: 30, conversionSource: "包装")
        let food = Food(name: "测试", nutrientsPer100Grams: Nutrients(energyKcal: 200), units: [unit])
        let entry = try NutritionCalculator.entry(food: food, quantity: 2, unit: unit, meal: .snack, at: Date())
        XCTAssertEqual(entry.grams, 60); XCTAssertEqual(entry.nutrients.energyKcal, 120)
        XCTAssertEqual(NutritionCalculator.kilocalories(fromKilojoules: 418.4), 100, accuracy: 0.000001)
        XCTAssertNil(entry.nutrients.proteinGrams)
    }
    func testZeroNegativeInfiniteAndUnownedPortionsAreRejected() {
        for quantity in [0.0, -1, .infinity, .nan] { XCTAssertThrowsError(try NutritionCalculator.grams(quantity: quantity, unit: nil)) }
        let food = Food(name: "测试", nutrientsPer100Grams: Nutrients())
        XCTAssertThrowsError(try NutritionCalculator.entry(food: food, quantity: 1, unit: FoodUnit(name: "假单位", grams: 10), meal: .lunch, at: Date()))
    }
    func testPartialUnknownTotalsAreNotZeroAndGoalsUseEffectiveDate() {
        let entries = [DietEntry(meal: .lunch, nutrients: Nutrients(energyKcal: 100, proteinGrams: 10)), DietEntry(meal: .snack, nutrients: Nutrients(energyKcal: 200))]
        let summary = NutritionSummary(entries: entries)
        XCTAssertEqual(summary.energy.known, 300); XCTAssertEqual(summary.protein.known, 10); XCTAssertEqual(summary.protein.missing, 1)
        XCTAssertNil(summary.fat.known); XCTAssertNil(NutritionSummary(entries: []).energy.known)
        let goals = [NutritionGoal(effectiveFrom: "2026-10-01", nutrients: Nutrients(energyKcal: 1800)), NutritionGoal(effectiveFrom: "2026-10-20", nutrients: Nutrients(energyKcal: 2200))]
        XCTAssertEqual(NutritionCalculator.goal(on: "2026-10-19", goals: goals)?.nutrients.energyKcal, 1800)
        XCTAssertEqual(NutritionCalculator.goal(on: "2026-10-20", goals: goals)?.nutrients.energyKcal, 2200)
        XCTAssertNil(NutritionCalculator.goal(on: "2026-09-30", goals: goals))
    }
    func testBundledCatalogIsValidSearchableAndSourced() throws {
        let foods = try FoodCatalog.load(); XCTAssertEqual(foods.count, 500)
        let rice = FoodCatalog.search(foods, query: "米饭").first { $0.source.reference?.contains("168878") == true }
        XCTAssertNotNil(rice); XCTAssertEqual(rice?.source.license, "CC0-1.0")
        XCTAssertTrue(rice?.source.reference?.contains("168878") ?? false)
        XCTAssertEqual(rice?.nutrientsPer100Grams.energyKcal, 130)
        XCTAssertTrue(FoodCatalog.search(foods, query: "BANANAS").contains { $0.name == "香蕉（生）" })
        XCTAssertTrue(foods.allSatisfy { !$0.units.contains { $0.grams <= 0 || $0.conversionSource == nil } })
    }
}
