import Foundation

enum FoodFilter: String, CaseIterable, Identifiable {
    case all, favorites, recent, custom
    var id: Self { self }
    var title: String { switch self { case .all: "全部"; case .favorites: "收藏"; case .recent: "最近"; case .custom: "自定义" } }
}

enum NutritionWorkflow {
    static func foods(catalog: [Food], records: [Food]) -> [Food] {
        var available = Dictionary(uniqueKeysWithValues: catalog.map { ($0.stamp.id, $0) })
        for stored in records {
            var food = stored
            if let current = available[stored.stamp.id] {
                // Upgrade discovery labels without changing stored nutrients,
                // units, user flags, revision or any historical snapshot.
                food.name = current.name
                food.aliases = Array(Set(stored.aliases + current.aliases + [stored.name])).sorted()
                food.category = current.category
            }
            available[food.stamp.id] = food
        }
        return available.values.filter { $0.stamp.deletedAt == nil }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func recentFoodIDs(_ entries: [DietEntry]) -> [UUID] {
        var seen = Set<UUID>()
        return entries.filter { $0.stamp.deletedAt == nil }.sorted {
            $0.occurred.instant == $1.occurred.instant ? $0.stamp.id.uuidString > $1.stamp.id.uuidString : $0.occurred.instant > $1.occurred.instant
        }.compactMap(\.food?.foodID).filter { seen.insert($0).inserted }.prefix(20).map { $0 }
    }

    static func search(_ foods: [Food], catalog: [Food], entries: [DietEntry], query: String,
                       filter: FoodFilter, category: String?, archived: Bool = false) -> [Food] {
        let recent = recentFoodIDs(entries)
        let known = Set(catalog.map { $0.stamp.id })
        let matching = FoodCatalog.search(foods, query: query, archived: archived).filter { food in
            (category == nil || (food.category ?? "未分类") == category) &&
            (filter != .favorites || food.isFavorite == true) &&
            (filter != .recent || recent.contains(food.stamp.id)) &&
            (filter != .custom || !known.contains(food.stamp.id))
        }
        guard filter == .recent else { return matching }
        let ranks = Dictionary(uniqueKeysWithValues: recent.enumerated().map { ($0.element, $0.offset) })
        return matching.sorted { ranks[$0.stamp.id, default: 20] < ranks[$1.stamp.id, default: 20] }
    }

    static func previousGrams(foodID: UUID, entries: [DietEntry]) -> Double? {
        entries.filter { $0.stamp.deletedAt == nil && $0.food?.foodID == foodID && $0.grams != nil }
            .max { $0.occurred.instant == $1.occurred.instant ? $0.stamp.id.uuidString < $1.stamp.id.uuidString : $0.occurred.instant < $1.occurred.instant }?.grams
    }
}
