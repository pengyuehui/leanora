import Foundation

struct NutritionContentCatalog: Decodable, Sendable {
    struct Recipe: Decodable, Identifiable, Sendable {
        struct Ingredient: Decodable, Sendable { var foodID: UUID; var grams: Double }
        var id: String
        var title: String
        var subtitle: String
        var notes: String
        var items: [Ingredient]
    }
    struct Guide: Decodable, Identifiable, Sendable {
        struct Section: Decodable, Sendable { var title: String; var paragraphs: [String] }
        var id: String
        var title: String
        var summary: String
        var sections: [Section]
    }
    var version: Int
    var author: String
    var license: String
    var recipes: [Recipe]
    var guides: [Guide]

    private static let bundled: Result<Self, Error> = Result {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "nutrition-content", withExtension: "json", subdirectory: "Catalog")
        #else
        let url = Bundle.main.url(forResource: "nutrition-content", withExtension: "json")
        #endif
        guard let url else { throw DataProblem.invalid("饮食内容文件缺失") }
        return try decode(Data(contentsOf: url), foods: FoodCatalog.load())
    }
    static func load() throws -> Self { try bundled.get() }
    static func decode(_ data: Data, foods: [Food]) throws -> Self {
        guard data.count <= 2 * 1024 * 1024 else { throw DataProblem.tooLarge }
        let document = try JSONDecoder().decode(Self.self, from: data)
        guard document.version == 1 else { throw DataProblem.unsupportedVersion }
        guard document.license == "MIT", !document.author.isEmpty, (1...100).contains(document.recipes.count),
              (1...100).contains(document.guides.count) else { throw DataProblem.invalid("饮食内容来源或数量") }
        let ids = document.recipes.map(\.id) + document.guides.map(\.id)
        guard Set(ids).count == ids.count, ids.allSatisfy({ !$0.isEmpty }) else { throw DataProblem.invalid("饮食内容标识") }
        for recipe in document.recipes {
            try DomainValidation.text(recipe.title, required: true); try DomainValidation.text(recipe.subtitle, required: true)
            try DomainValidation.text(recipe.notes, required: true)
            _ = try document.draft(recipeID: recipe.id, foods: foods)
        }
        for guide in document.guides {
            try DomainValidation.text(guide.title, required: true); try DomainValidation.text(guide.summary, required: true)
            guard (1...20).contains(guide.sections.count) else { throw DataProblem.invalid("饮食指南章节") }
            for section in guide.sections {
                try DomainValidation.text(section.title, required: true)
                guard (1...20).contains(section.paragraphs.count) else { throw DataProblem.invalid("饮食指南正文") }
                for paragraph in section.paragraphs { try DomainValidation.text(paragraph, required: true) }
            }
        }
        return document
    }
    func draft(recipeID: String, foods: [Food]) throws -> MealTemplate {
        guard let recipe = recipes.first(where: { $0.id == recipeID }), (1...50).contains(recipe.items.count) else { throw DataProblem.invalid("搭配范例") }
        let available = Dictionary(uniqueKeysWithValues: foods.map { ($0.stamp.id, $0) })
        let entries = try recipe.items.map { ingredient in
            guard let food = available[ingredient.foodID] else { throw TrainingProblem.missingRecord }
            return try NutritionCalculator.entry(food: food, quantity: ingredient.grams, unit: nil, meal: .lunch, at: Date())
        }
        var draft = try MealTemplate.draft(name: recipe.title, entries: entries); draft.notes = recipe.notes
        return draft
    }
}
