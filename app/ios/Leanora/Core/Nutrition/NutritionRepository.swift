import Foundation

extension AppModelActor {
    func nutritionFoods(catalog: [Food]) throws -> [Food] {
        NutritionWorkflow.foods(catalog: catalog, records: try snapshot().compactMap { if case .food(let v) = $0 { return v }; return nil })
    }

    func setFoodFavorite(_ id: UUID, favorite: Bool, catalog: [Food]) throws {
        let records = try snapshot()
        guard var value = try nutritionFoods(catalog: catalog).first(where: { $0.stamp.id == id }) else { throw TrainingProblem.missingRecord }
        guard (value.isFavorite == true) != favorite else { return }
        value.isFavorite = favorite ? true : nil
        if records.contains(where: { $0.id == id }) { value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt) }
        try save([.food(value)])
    }

    func mealDraft(from day: String, meal: Meal) throws -> MealTemplate {
        try DomainValidation.day(day)
        let entries = try snapshot().compactMap { record -> DietEntry? in
            if case .diet(let v) = record, v.stamp.deletedAt == nil, v.occurred.localDate == day, v.meal == meal { return v }; return nil
        }.sorted { $0.occurred.instant == $1.occurred.instant ? $0.stamp.id.uuidString < $1.stamp.id.uuidString : $0.occurred.instant < $1.occurred.instant }
        return try MealTemplate.draft(name: "我的\(meal.title)组合", entries: entries)
    }

    func saveMealTemplate(_ draft: MealTemplate, catalog: [Food]) throws -> MealTemplate {
        let records = try snapshot(); var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .mealTemplate(let old) = records.first(where: { $0.id == value.id }) {
            guard old.stamp.deletedAt == nil, old.stamp.revision == draft.stamp.revision else { throw DataProblem.revisionConflict }
            value.stamp = old.stamp; value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), old.stamp.updatedAt)
        }
        value.items = value.items.enumerated().map { index, item in var v = item; v.order = index; return v }
        let dependencies = try foodDependencies(value.items.compactMap(\.food), records: records, catalog: catalog)
        try save(dependencies + [.mealTemplate(value)]); return value
    }

    func deleteMealTemplate(_ draft: MealTemplate) throws {
        guard case .mealTemplate(var value) = try snapshot().first(where: { $0.id == draft.id }),
              value.stamp.revision == draft.stamp.revision, value.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
        value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt); value.stamp.deletedAt = value.stamp.updatedAt
        try save([.mealTemplate(value)])
    }

    func recordMeal(_ entries: [DietEntry], catalog: [Food]) throws {
        guard (1...50).contains(entries.count), Set(entries.map { $0.stamp.id }).count == entries.count else { throw DataProblem.invalid("组合记录数量或 ID") }
        let records = try snapshot()
        let existing = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        // Retrying an already committed batch returns without recreating jobs.
        if entries.allSatisfy({ entry in
            guard let old = existing[entry.stamp.id] else { return false }
            return (try? RecordCoding.encode(old)) == (try? RecordCoding.encode(BusinessRecord.diet(entry)))
        }) { return }
        guard entries.allSatisfy({ existing[$0.stamp.id] == nil && $0.stamp.revision == 1 && $0.stamp.deletedAt == nil }) else { throw DataProblem.revisionConflict }
        for entry in entries { try MealTemplateItem(entry: entry, order: 0).validate() }
        let dependencies = try foodDependencies(entries.compactMap(\.food), records: records, catalog: catalog)
        try saveWithHealthIntent(dependencies + entries.map(BusinessRecord.diet))
    }

    private func foodDependencies(_ snapshots: [FoodSnapshot], records: [BusinessRecord], catalog: [Food]) throws -> [BusinessRecord] {
        let persisted = Set(records.filter { $0.kind == "food" }.map(\.id))
        var needed: [UUID: Food] = [:]
        for snapshot in snapshots where !persisted.contains(snapshot.foodID) {
            guard let food = catalog.first(where: { $0.stamp.id == snapshot.foodID }), FoodSnapshot(food) == snapshot else { throw TrainingProblem.missingRecord }
            needed[snapshot.foodID] = food
        }
        return needed.values.map(BusinessRecord.food)
    }

    func saveCustomFood(_ draft: Food, catalog: [Food]) throws {
        guard !catalog.contains(where: { $0.stamp.id == draft.stamp.id }) else { throw DataProblem.invalid("基础食物不可直接改写") }
        var food = draft; food.name = food.name.trimmingCharacters(in: .whitespacesAndNewlines); food.source = ContentSource()
        if case .food(let old) = try snapshot().first(where: { $0.id == food.stamp.id }) {
            guard old.stamp.revision == draft.stamp.revision, old.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
            food.stamp.revision += 1; food.stamp.updatedAt = max(Date(), old.stamp.updatedAt)
        }
        try save([.food(food)])
    }

    func saveDiet(_ draft: DietEntry, catalog: [Food]) throws {
        let records = try snapshot(); var value = draft; var changes: [BusinessRecord] = []
        if case .diet(let old) = records.first(where: { $0.id == draft.stamp.id }) {
            guard old.stamp.revision == draft.stamp.revision, old.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
            value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), old.stamp.updatedAt)
        }
        if let snapshot = value.food, !records.contains(where: { $0.id == snapshot.foodID }) {
            guard let food = catalog.first(where: { $0.stamp.id == snapshot.foodID }), FoodSnapshot(food) == snapshot else { throw TrainingProblem.missingRecord }
            changes.append(.food(food))
        }
        if let food = value.food, let grams = value.grams, food.nutrientsPer100Grams.scaled(by: grams / 100) != value.nutrients { throw DataProblem.invalid("营养快照计算") }
        changes.append(.diet(value)); try saveWithHealthIntent(changes)
    }

    func deleteDiet(_ id: UUID, revision: Int, deleteHealthCopies: Bool = false) throws {
        guard case .diet(var value) = try snapshot().first(where: { $0.id == id }), value.stamp.revision == revision, value.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
        value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt); value.stamp.deletedAt = value.stamp.updatedAt
        try saveWithHealthIntent([.diet(value)], deleteHealthCopies: deleteHealthCopies)
    }

    func copyMeal(from day: String, meal: Meal, to date: Date, destinationMeal: Meal, timeZoneID: String = TimeZone.current.identifier) throws -> Int {
        try DomainValidation.day(day)
        let copies = try snapshot().compactMap { record -> BusinessRecord? in
            guard case .diet(var entry) = record, entry.stamp.deletedAt == nil, entry.occurred.localDate == day, entry.meal == meal else { return nil }
            entry.stamp = RecordStamp(); entry.occurred = RecordMoment(date, timeZoneID: timeZoneID); entry.meal = destinationMeal
            return .diet(entry)
        }
        guard !copies.isEmpty else { throw DataProblem.invalid("所选餐次没有可复制记录") }
        try saveWithHealthIntent(copies); return copies.count
    }

    func saveMeasurement(_ draft: BodyMeasurement) throws {
        var value = draft; value.source = ContentSource()
        if case .measurement(let old) = try snapshot().first(where: { $0.id == draft.stamp.id }) {
            guard old.stamp.revision == draft.stamp.revision, old.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
            value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), old.stamp.updatedAt)
        }
        try saveWithHealthIntent([.measurement(value)])
    }
    func deleteMeasurement(_ id: UUID, revision: Int, deleteHealthCopies: Bool = false) throws {
        guard case .measurement(var value) = try snapshot().first(where: { $0.id == id }), value.stamp.revision == revision, value.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
        value.stamp.revision += 1; value.stamp.updatedAt = max(Date(), value.stamp.updatedAt); value.stamp.deletedAt = value.stamp.updatedAt
        try saveWithHealthIntent([.measurement(value)], deleteHealthCopies: deleteHealthCopies)
    }
}
