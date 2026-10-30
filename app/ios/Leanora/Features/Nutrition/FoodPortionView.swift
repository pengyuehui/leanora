import SwiftUI

struct FoodPortionView: View {
    let food: Food
    var existing: DietEntry?
    let onSaved: () -> Void
    let onDraft: ((DietEntry) -> Void)?
    @Environment(JournalStore.self) private var journal
    @State private var quantity = "100"
    @State private var unitID: UUID?
    @State private var meal: Meal
    @State private var date: Date
    @State private var notes = ""
    @State private var editing = false
    @State private var confirming = false
    @State private var error: String?
    @FocusState private var focused: Bool
    init(food: Food, meal: Meal, date: Date, existing: DietEntry? = nil, onDraft: ((DietEntry) -> Void)? = nil, onSaved: @escaping () -> Void) {
        self.food = food; self.existing = existing; self.onSaved = onSaved; self.onDraft = onDraft
        _meal = State(initialValue: meal); _date = State(initialValue: date)
        _quantity = State(initialValue: numeric(existing?.grams) == "" ? "100" : numeric(existing?.grams))
        _notes = State(initialValue: existing?.notes ?? "")
    }
    var body: some View {
        Form {
            Section {
                Text(food.name).font(.headline)
                Text(food.source.name).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("food.source")
                if existing == nil {
                    let favorite = journal.foods.first { $0.id == food.id }?.isFavorite == true
                    Button(favorite ? "取消收藏" : "收藏食物", systemImage: favorite ? "star.fill" : "star") {
                        Task { _ = await journal.run { [repository = journal.repository, catalog = journal.catalog] in try await repository.setFoodFavorite(food.id, favorite: !favorite, catalog: catalog) } }
                    }.disabled(journal.busy).accessibilityIdentifier("portion.favorite")
                }
            }
            Section("本次食用") {
                Picker("数量单位", selection: Binding(get: { unitID }, set: { unitID = $0; quantity = $0 == nil ? "100" : "1" })) {
                    Text("g").tag(UUID?.none)
                    ForEach(food.units, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }.accessibilityIdentifier("portion.unit")
                LabeledContent("数量") {
                    HStack {
                        TextField("数量", text: $quantity).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused).accessibilityIdentifier("portion.quantity")
                        Button { quantity = "" } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel("清空数量").accessibilityIdentifier("portion.clear")
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack { gramShortcuts }
                    VStack(alignment: .leading) { gramShortcuts }
                }
                if existing == nil, let grams = NutritionWorkflow.previousGrams(foodID: food.id, entries: journal.entries) {
                    Button("使用上次 \(grams.formatted()) g") { unitID = nil; quantity = numeric(grams) }.accessibilityIdentifier("portion.previous")
                }
                if let unit = selectedUnit { Text("1 \(unit.name) = \(unit.grams.formatted()) g").font(.caption).foregroundStyle(.secondary) }
                Picker("餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.title).tag($0) } }
                RecordDatePicker(title: "食用时间", selection: $date)
                TextField("备注（可选）", text: $notes, axis: .vertical).focused($focused)
            }
            if let preview = try? makeEntry() { Section("按本次数量计算") { NutritionSummaryView(summary: NutritionSummary(entries: [preview])) } }
            Section { DisclosureGroup("份量与来源") {
                Text(food.source.license ?? "用户输入").font(.caption)
                if let reference = food.source.reference { Text(reference).font(.caption).textSelection(.enabled) }
                if let unit = selectedUnit { Text(unit.conversionSource ?? food.source.name).font(.caption) }
                Text("核对生熟、去皮和可食重量。来源份量与实物大小可能不同，可以按实际称重记录。").font(.caption)
            } }
            if let error { Text(error).accessibilityIdentifier("portion.error") }
            JournalErrorNotice()
            if !journal.catalog.contains(where: { $0.id == food.id }), existing == nil {
                Section { Button("编辑或归档此自定义食物") { editing = true }.accessibilityIdentifier("food.edit") }
            }
        }
        .navigationTitle(onDraft != nil ? "组合食物份量" : (existing == nil ? "记录食物" : "编辑饮食记录")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("portion.keyboardDone") }.padding(.horizontal).background(.bar) } }
        .toolbar {
            if existing != nil { ToolbarItem(placement: .cancellationAction) { Button("取消") { onSaved() } } }
            ToolbarItem(placement: .confirmationAction) { Button(onDraft == nil ? "保存" : "加入组合") {
                if let existing, existing.occurred.localDate != RecordMoment(date).localDate { confirming = true } else { save() }
            }.disabled(journal.busy || food.isArchived).accessibilityIdentifier("portion.save") }
        }
        .confirmationDialog("记录将归属新的日期，确认保存？", isPresented: $confirming, titleVisibility: .visible) { Button("确认更改日期") { save() } }
        .sheet(isPresented: $editing) { NavigationStack { CustomFoodView(original: journal.foods.first { $0.id == food.id } ?? food) } }
        .onChange(of: editing) { _, isEditing in if !isEditing { onSaved() } }
    }
    private var selectedUnit: FoodUnit? { food.units.first { $0.id == unitID } }
    private var gramShortcuts: some View {
        ForEach([50,100,150], id: \.self) { grams in
            Button("\(grams) g") { unitID = nil; quantity = String(grams) }.buttonStyle(.bordered)
                .accessibilityIdentifier("portion.grams.\(grams)")
        }
    }
    private func makeEntry() throws -> DietEntry {
        guard let quantity = try TrainingTargetInput.decimal(quantity) else { throw DataProblem.invalid("食用数量") }
        var entry = try NutritionCalculator.entry(food: food, quantity: quantity, unit: selectedUnit, meal: meal, at: date)
        if let existing { entry.stamp = existing.stamp }
        entry.notes = notes; return entry
    }
    private func save() {
        do { let entry = try makeEntry()
            if let onDraft { onDraft(entry); onSaved(); return }
            Task {
            if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in try await repository.saveDiet(entry, catalog: catalog) }) != nil { onSaved() }
        } } catch { self.error = error.localizedDescription }
    }
}

struct QuickCaloriesView: View {
    var existing: DietEntry?
    var onDraft: ((DietEntry) -> Void)?
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var meal = Meal.snack
    @State private var name = ""
    @State private var energy = ""
    @State private var notes = ""
    @State private var kj = false
    @State private var error: String?
    @State private var confirming = false
    @FocusState private var focused: Bool
    init(date: Date, existing: DietEntry? = nil, onDraft: ((DietEntry) -> Void)? = nil) { self.existing = existing; self.onDraft = onDraft; _date = State(initialValue: date) }
    var body: some View {
        Form {
            Section {
                TextField("名称（可留空）", text: $name).focused($focused).accessibilityIdentifier("quick.name")
                Toggle("热量单位 kJ", isOn: $kj)
                LabeledContent(kj ? "热量（kJ）" : "热量（kcal）") { TextField("必填", text: $energy).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("quick.energy") }
                Picker("餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.title).tag($0) } }
                RecordDatePicker(title: "食用时间", selection: $date)
                TextField("备注（可选）", text: $notes).focused($focused)
                Text("只记录热量，蛋白质、碳水和脂肪保持未知。")
            }
            if let error { Text(error).accessibilityIdentifier("quick.error") }
            JournalErrorNotice()
        }.navigationTitle("快速记热量").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("quick.keyboardDone") }.padding(.horizontal).background(.bar) } }
            .task { if let existing { name = existing.name; energy = numeric(existing.nutrients.energyKcal); meal = existing.meal; notes = existing.notes } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(onDraft == nil ? "保存" : "加入组合") {
                    if let existing, existing.occurred.localDate != RecordMoment(date).localDate { confirming = true } else { save() }
                }.disabled(journal.busy).accessibilityIdentifier("quick.save") }
            }
            .confirmationDialog("记录将归属新的日期，确认保存？", isPresented: $confirming, titleVisibility: .visible) { Button("确认更改日期") { save() } }
    }
    private func save() {
        do {
            guard let number = try TrainingTargetInput.decimal(energy) else { throw DataProblem.invalid("快速记录热量必填") }
            var value = DietEntry(occurred: RecordMoment(date), meal: meal, name: name, nutrients: Nutrients(energyKcal: kj ? NutritionCalculator.kilocalories(fromKilojoules: number) : number), notes: notes)
            if let existing { value.stamp = existing.stamp }
            let entry = value
            try MealTemplateItem(entry: entry, order: 0).validate()
            if let onDraft { onDraft(entry); dismiss(); return }
            Task { if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in try await repository.saveDiet(entry, catalog: catalog) }) != nil { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}
