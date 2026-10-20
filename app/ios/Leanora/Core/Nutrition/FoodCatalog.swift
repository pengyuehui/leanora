import Foundation

struct FoodCatalog: Decodable {
    struct Entry: Decodable {
        var id: UUID
        var name: String
        var aliases: [String]
        var nutrients: Nutrients
        var units: [FoodUnit]
        var reference: String
    }
    var version: Int
    var entries: [Entry]
    static func load() throws -> [Food] {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "foods", withExtension: "json", subdirectory: "Catalog")
        #else
        let url = Bundle.main.url(forResource: "foods", withExtension: "json")
        #endif
        guard let url else { throw DataProblem.invalid("食物目录缺失") }
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard catalog.version == 1 else { throw DataProblem.unsupportedVersion }
        let date = Date(timeIntervalSince1970: 1_792_454_400)
        let foods = catalog.entries.map { entry in
            Food(stamp: RecordStamp(id: entry.id, createdAt: date, updatedAt: date), name: entry.name, aliases: entry.aliases,
                 nutrientsPer100Grams: entry.nutrients, units: entry.units,
                 source: ContentSource(name: "USDA FoodData Central · SR Legacy 2018", license: "CC0-1.0", reference: entry.reference))
        }
        try DomainValidation.validate(foods.map(BusinessRecord.food), requireProfile: false)
        return foods
    }
    static func search(_ foods: [Food], query: String, archived: Bool = false) -> [Food] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return foods.filter { food in
            food.stamp.deletedAt == nil && food.isArchived == archived && words.allSatisfy { word in ([food.name] + food.aliases).contains { $0.localizedStandardContains(word) } }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
