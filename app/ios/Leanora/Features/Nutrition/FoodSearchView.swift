import SwiftUI

struct FoodSearchView: View {
    @Environment(JournalStore.self) private var journal
    let meal: Meal
    let date: Date
    let onAdded: () -> Void
    let onDraft: ((DietEntry) -> Void)?
    @State private var query = ""
    @State private var custom = false
    @State private var archived = false
    @State private var filter = FoodFilter.all
    @State private var category: String?

    init(meal: Meal, date: Date, onDraft: ((DietEntry) -> Void)? = nil, onAdded: @escaping () -> Void) {
        self.meal = meal; self.date = date; self.onDraft = onDraft; self.onAdded = onAdded
    }
    var body: some View {
        List {
            JournalErrorNotice()
            Section {
                Button("自定义食物") { custom = true }.accessibilityIdentifier("food.custom")
                Picker("查看", selection: $filter) { ForEach(FoodFilter.allCases) { Text($0.title).tag($0) } }
                    .accessibilityIdentifier("food.filter")
                Picker("分类", selection: $category) {
                    Text("全部分类").tag(String?.none)
                    ForEach(Array(Set(journal.foods.map { $0.category ?? "未分类" })).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                }.accessibilityIdentifier("food.category")
                DisclosureGroup("目录与筛选") {
                    Toggle("查看已归档食物", isOn: $archived)
                    Text("离线基础目录 \(journal.catalog.count) 条 · USDA SR Legacy。烹调方式影响营养，请核对条目；未收录的食物可自行输入。").font(.caption).foregroundStyle(.secondary)
                }
            }
            let foods = NutritionWorkflow.search(journal.foods, catalog: journal.catalog, entries: journal.entries,
                                                 query: query, filter: filter, category: category, archived: archived)
            if foods.isEmpty {
                ContentUnavailableView("没有符合条件的食物", systemImage: "magnifyingglass", description: Text("试试其他名称，或返回全部分类。未收录的食品可以自定义。"))
                Button("查看全部食物") { filter = .all; category = nil; archived = false; query = "" }.accessibilityIdentifier("food.clearFilters")
            }
            Section("\(filter.title) · \(foods.count) 项") { ForEach(foods) { food in foodLink(food) } }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索名称、中文或英文别名")
        .navigationTitle("添加\(meal.title)")
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { onAdded() } } }
        .sheet(isPresented: $custom) { NavigationStack { CustomFoodView() } }
    }
    private func foodLink(_ food: Food) -> some View {
        NavigationLink { FoodPortionView(food: food, meal: meal, date: date, onDraft: onDraft, onSaved: onAdded) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(food.name, systemImage: food.isFavorite == true ? "star.fill" : "fork.knife")
                Text("\(food.nutrientsPer100Grams.energyKcal.map { $0.formatted() } ?? "未知") kcal / 100 g · \(food.category ?? "自定义")").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }.accessibilityIdentifier("food.select.\(food.name)")
            .swipeActions(edge: .leading) {
                Button(food.isFavorite == true ? "取消收藏" : "收藏", systemImage: food.isFavorite == true ? "star.slash" : "star") {
                    Task { _ = await journal.run { [repository = journal.repository, catalog = journal.catalog] in try await repository.setFoodFavorite(food.id, favorite: food.isFavorite != true, catalog: catalog) } }
                }.tint(.orange)
            }
    }
}

struct CustomFoodView: View {
    var original: Food?
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var aliases = ""
    @State private var energy = ""
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var portion = ""
    @State private var portionGrams = ""
    @State private var kilojoules = false
    @State private var archived = false
    @State private var error: String?
    @FocusState private var focused: Bool
    var body: some View {
        Form {
            Section("食物资料") {
                TextField("食物名称", text: $name).focused($focused).accessibilityIdentifier("food.name")
                TextField("别名（逗号分隔）", text: $aliases).focused($focused)
                Toggle("已归档", isOn: $archived)
            }
            Section("每 100 g 的营养（未知请留空）") {
                Toggle("热量输入单位为 kJ", isOn: $kilojoules)
                field(kilojoules ? "热量（kJ）" : "热量（kcal）", $energy, "energy")
                field("蛋白质（g）", $protein, "protein"); field("碳水（g）", $carbohydrate, "carbohydrate"); field("脂肪（g）", $fat, "fat")
            }
            Section("自定义一份（可选）") {
                TextField("单位名称，例如：袋", text: $portion).focused($focused).accessibilityIdentifier("food.portionName")
                field("一份重量（g）", $portionGrams, "portionGrams")
                Text("只使用包装标识或实际称重的重量，不把体积直接当成克数。").font(.caption)
            }
            if let error { Text(error).accessibilityIdentifier("food.error") }
            JournalErrorNotice()
        }
        .navigationTitle(original == nil ? "自定义食物" : "编辑自定义食物").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("food.keyboardDone") }.padding(.horizontal).background(.bar) } }
        .task {
            guard let original else { return }
            name = original.name; aliases = original.aliases.joined(separator: ", "); archived = original.isArchived
            energy = numeric(original.nutrientsPer100Grams.energyKcal); protein = numeric(original.nutrientsPer100Grams.proteinGrams)
            carbohydrate = numeric(original.nutrientsPer100Grams.carbohydrateGrams); fat = numeric(original.nutrientsPer100Grams.fatGrams)
            portion = original.units.first?.name ?? ""; portionGrams = numeric(original.units.first?.grams)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(journal.busy).accessibilityIdentifier("food.save") }
        }
    }
    private func field(_ title: String, _ text: Binding<String>, _ id: String) -> some View {
        LabeledContent(title) { TextField("未知", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused).accessibilityIdentifier("food.\(id)") }
    }
    private func save() {
        do {
            let kcal = try TrainingTargetInput.decimal(energy).map { kilojoules ? NutritionCalculator.kilocalories(fromKilojoules: $0) : $0 }
            let nutrients = try Nutrients(energyKcal: kcal, proteinGrams: TrainingTargetInput.decimal(protein), carbohydrateGrams: TrainingTargetInput.decimal(carbohydrate), fatGrams: TrainingTargetInput.decimal(fat))
            var value = original ?? Food(name: name, nutrientsPer100Grams: nutrients)
            value.name = name; value.aliases = aliases.split(whereSeparator: { $0 == "," || $0 == "，" }).map { $0.trimmingCharacters(in: .whitespaces) }
            value.nutrientsPer100Grams = nutrients; value.isArchived = archived
            if !portion.isEmpty || !portionGrams.isEmpty {
                guard let grams = try TrainingTargetInput.decimal(portionGrams), !portion.trimmingCharacters(in: .whitespaces).isEmpty else { throw DataProblem.invalid("份量名称与重量") }
                value.units = [FoodUnit(id: original?.units.first?.id ?? UUID(), name: portion, grams: grams, conversionSource: "用户提供包装标识或称重")]
            } else { value.units = [] }
            let draft = value
            Task { if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in try await repository.saveCustomFood(draft, catalog: catalog) }) != nil { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}

func numeric(_ number: Double?) -> String { number.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...4))) } ?? "" }
