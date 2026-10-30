import Foundation

struct Nutrients: Codable, Equatable, Sendable {
    var energyKcal: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?

    func scaled(by factor: Double) -> Self {
        Self(energyKcal: energyKcal.map { $0 * factor }, proteinGrams: proteinGrams.map { $0 * factor },
             carbohydrateGrams: carbohydrateGrams.map { $0 * factor }, fatGrams: fatGrams.map { $0 * factor })
    }
}
struct FoodUnit: Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var grams: Double
    // A volume is only convertible when an explicitly sourced gram equivalent exists.
    var milliliters: Double?
    var conversionSource: String?
}
struct Food: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var name: String
    var aliases: [String] = []
    var nutrientsPer100Grams: Nutrients
    var units: [FoodUnit] = []
    var source = ContentSource()
    var isArchived = false
    var isFavorite: Bool?
    var category: String?
}
enum Meal: String, Codable, Sendable { case breakfast, lunch, dinner, snack }
struct FoodSnapshot: Codable, Equatable, Sendable {
    var foodID: UUID
    var revision: Int
    var name: String
    var nutrientsPer100Grams: Nutrients
    var source: ContentSource

    init(_ food: Food) {
        foodID = food.stamp.id; revision = food.stamp.revision; name = food.name
        nutrientsPer100Grams = food.nutrientsPer100Grams; source = food.source
    }
}
struct DietEntry: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var occurred = RecordMoment()
    var meal: Meal
    var name: String = ""
    var food: FoodSnapshot?
    var quantity: Double = 1
    var unitName: String = "次"
    var grams: Double?
    var nutrients: Nutrients
    var notes = ""
}
struct NutritionGoal: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var effectiveFrom: String
    var timeZoneID = TimeZone.current.identifier
    var nutrients: Nutrients
}
enum BodyMetric: String, Codable, Sendable { case weightKg, bodyFatPercent }
struct BodyMeasurement: Codable, Equatable, Sendable {
    var stamp = RecordStamp()
    var occurred = RecordMoment()
    var metric: BodyMetric
    var value: Double
    var source = ContentSource()
}
