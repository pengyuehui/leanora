import Foundation

struct MealTemplateItem: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var order: Int
    var name: String
    var food: FoodSnapshot?
    var quantity: Double
    var unitName: String
    var grams: Double?
    var nutrients: Nutrients
    var notes: String

    init(entry: DietEntry, order: Int) {
        self.order = order; name = entry.name; food = entry.food
        quantity = entry.quantity; unitName = entry.unitName; grams = entry.grams
        nutrients = entry.nutrients; notes = entry.notes
    }

    func entry(servings: Double, meal: Meal, date: Date, timeZoneID: String = TimeZone.current.identifier) -> DietEntry {
        let scaledGrams = grams.map { $0 * servings }
        // Calculate food values with the same operation order as saveDiet.
        let scaled = if let food, let scaledGrams { food.nutrientsPer100Grams.scaled(by: scaledGrams / 100) }
                     else { nutrients.scaled(by: servings) }
        return DietEntry(occurred: RecordMoment(date, timeZoneID: timeZoneID), meal: meal, name: name, food: food,
                         quantity: quantity * servings, unitName: unitName, grams: scaledGrams, nutrients: scaled, notes: notes)
    }

    func validate() throws {
        try DomainValidation.text(name); try DomainValidation.text(unitName, required: true); try DomainValidation.text(notes)
        try DomainValidation.number(quantity, min: 0.000001, max: 100_000)
        try DomainValidation.number(grams, min: 0.000001, max: 100_000)
        try DomainValidation.nutrients(nutrients)
        if let food {
            try DomainValidation.text(food.name, required: true); try DomainValidation.nutrients(food.nutrientsPer100Grams)
            try DomainValidation.source(food.source)
            guard food.revision > 0, let grams else { throw DataProblem.invalid("组合食品快照") }
            let expected = food.nutrientsPer100Grams.scaled(by: grams / 100)
            guard expected == nutrients else { throw DataProblem.invalid("组合营养计算") }
        } else {
            guard nutrients.energyKcal != nil, grams == nil else { throw DataProblem.invalid("组合快速热量") }
        }
    }
}

struct MealTemplate: Codable, Equatable, Sendable, Identifiable {
    var stamp = RecordStamp()
    var name: String
    var notes = ""
    var items: [MealTemplateItem]
    var id: UUID { stamp.id }

    static func draft(name: String, entries: [DietEntry]) throws -> Self {
        let live = entries.filter { $0.stamp.deletedAt == nil }
        guard (1...50).contains(live.count) else { throw DataProblem.invalid("组合需要 1 至 50 项") }
        let draft = Self(name: name, items: live.enumerated().map { MealTemplateItem(entry: $0.element, order: $0.offset) })
        try draft.validate(); return draft
    }
    func validate() throws {
        try DomainValidation.text(name, required: true); try DomainValidation.text(notes)
        guard (1...50).contains(items.count) else { throw DataProblem.invalid("组合需要 1 至 50 项") }
        guard Set([id] + items.map(\.id)).count == items.count + 1 else { throw DataProblem.invalid("组合重复 UUID") }
        try DomainValidation.orders(items.map(\.order))
        for item in items { try item.validate() }
    }
    func entries(servings: Double, meal: Meal, date: Date, timeZoneID: String = TimeZone.current.identifier) throws -> [DietEntry] {
        try validate()
        guard stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        try DomainValidation.number(servings, min: 0.01, max: 100)
        let entries = items.sorted { $0.order < $1.order }.map { $0.entry(servings: servings, meal: meal, date: date, timeZoneID: timeZoneID) }
        for entry in entries { try MealTemplateItem(entry: entry, order: 0).validate(); try DomainValidation.moment(entry.occurred) }
        return entries
    }
    func copied() -> Self {
        var value = self; value.stamp = RecordStamp(); value.name += " · 副本"
        value.items = items.map { item in var copy = item; copy.id = UUID(); return copy }
        return value
    }
}
