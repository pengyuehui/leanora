import Foundation

enum NutritionCalculator {
    static func kilocalories(fromKilojoules value: Double) -> Double { value / 4.184 }
    static func grams(quantity: Double, unit: FoodUnit?) throws -> Double {
        let result = quantity * (unit?.grams ?? 1)
        try DomainValidation.number(quantity, min: 0.000001, max: 100_000)
        try DomainValidation.number(result, min: 0.000001, max: 100_000)
        return result
    }
    static func entry(food: Food, quantity: Double, unit: FoodUnit?, meal: Meal, at: Date, timeZoneID: String = TimeZone.current.identifier) throws -> DietEntry {
        guard !food.isArchived, food.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        if let unit, !food.units.contains(unit) { throw DataProblem.invalid("食物单位") }
        let grams = try grams(quantity: quantity, unit: unit)
        return DietEntry(occurred: RecordMoment(at, timeZoneID: timeZoneID), meal: meal, name: food.name, food: FoodSnapshot(food),
                         quantity: quantity, unitName: unit?.name ?? "g", grams: grams, nutrients: food.nutrientsPer100Grams.scaled(by: grams / 100))
    }
    static func goal(on day: String, goals: [NutritionGoal]) -> NutritionGoal? {
        goals.filter { $0.stamp.deletedAt == nil && $0.effectiveFrom <= day }.sorted {
            if $0.effectiveFrom != $1.effectiveFrom { return $0.effectiveFrom > $1.effectiveFrom }
            return $0.stamp.updatedAt > $1.stamp.updatedAt
        }.first
    }
}

struct NutrientTotal: Equatable, Sendable {
    var known: Double?
    var missing: Int
    var text: String { known.map { $0.formatted(.number.precision(.fractionLength(0...1))) + (missing > 0 ? "（部分）" : "") } ?? "未知" }
}
struct NutritionSummary: Equatable, Sendable {
    var count: Int
    var energy: NutrientTotal
    var protein: NutrientTotal
    var carbohydrate: NutrientTotal
    var fat: NutrientTotal
    init(entries: [DietEntry], on day: String? = nil, meal: Meal? = nil) {
        let values = entries.filter { $0.stamp.deletedAt == nil && (day == nil || $0.occurred.localDate == day) && (meal == nil || $0.meal == meal) }
        count = values.count
        func sum(_ key: KeyPath<Nutrients, Double?>) -> NutrientTotal {
            let known = values.compactMap { $0.nutrients[keyPath: key] }
            return NutrientTotal(known: known.isEmpty ? nil : known.reduce(0, +), missing: values.count - known.count)
        }
        energy = sum(\.energyKcal); protein = sum(\.proteinGrams); carbohydrate = sum(\.carbohydrateGrams); fat = sum(\.fatGrams)
    }
}

enum BodySummary {
    static func dailyLatest(_ values: [BodyMeasurement], metric: BodyMetric) -> [BodyMeasurement] {
        let live = values.filter { $0.stamp.deletedAt == nil && $0.metric == metric }
        return Dictionary(grouping: live, by: { $0.occurred.localDate }).values.compactMap { group in
            group.max { a, b in a.occurred.instant == b.occurred.instant ? a.stamp.id.uuidString < b.stamp.id.uuidString : a.occurred.instant < b.occurred.instant }
        }.sorted { $0.occurred.localDate < $1.occurred.localDate }
    }
    static func average(_ values: [BodyMeasurement], metric: BodyMetric, from: String, through: String) -> Double? {
        let daily = dailyLatest(values, metric: metric).filter { $0.occurred.localDate >= from && $0.occurred.localDate <= through }
        return daily.isEmpty ? nil : daily.map(\.value).reduce(0, +) / Double(daily.count)
    }
}

extension Meal: CaseIterable {
    static var allCases: [Self] { [.breakfast, .lunch, .dinner, .snack] }
    var title: String { switch self { case .breakfast: "早餐"; case .lunch: "午餐"; case .dinner: "晚餐"; case .snack: "加餐" } }
}
extension BodyMetric: CaseIterable {
    static var allCases: [Self] { [.weightKg, .bodyFatPercent] }
    var title: String { self == .weightKg ? "体重" : "体脂率" }
}
