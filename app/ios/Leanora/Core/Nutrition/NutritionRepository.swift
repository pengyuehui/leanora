import Foundation

extension AppModelActor {
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
