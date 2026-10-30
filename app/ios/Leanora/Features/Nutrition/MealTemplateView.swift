import SwiftUI

struct MealTemplatesView: View {
    @Environment(JournalStore.self) private var journal
    let date: Date
    @State private var editing: MealTemplate?
    @State private var removing: MealTemplate?
    var body: some View {
        List {
            Section {
                Text("把常吃的一餐，留给下次").font(.title2.bold())
                Text("一份就是组合中保存的整组食物。记录时可以选半份或多份，所有明细都可单独修改。").foregroundStyle(.secondary)
                Button("新建组合", systemImage: "plus") { editing = MealTemplate(name: "我的组合", items: []) }
                    .accessibilityIdentifier("mealTemplate.new")
            }
            JournalErrorNotice()
            if journal.mealTemplates.isEmpty { ContentUnavailableView("还没有组合餐", systemImage: "fork.knife", description: Text("新建组合，或将日记中的一餐存为组合。")) }
            Section("我的组合") {
                ForEach(journal.mealTemplates) { template in
                    NavigationLink { MealTemplateDetailView(templateID: template.id, date: date) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(template.name).font(.headline)
                            Text("\(template.items.count) 项 · 一份已知热量 \(summary(template).energy.text) kcal").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("mealTemplate.open.\(template.name)")
                        .swipeActions { Button("删除", role: .destructive) { removing = template } }
                }
            }
            Section { NavigationLink("浏览原创搭配范例") { NutritionExamplesView() } }
        }.navigationTitle("我的组合餐").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .sheet(item: $editing) { draft in NavigationStack { MealTemplateEditorView(draft: draft) } }
            .confirmationDialog("删除这个组合？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("确认删除组合", role: .destructive) {
                    if let value = removing { Task { _ = await journal.run { [repository = journal.repository] in try await repository.deleteMealTemplate(value) }; removing = nil } }
                }
            } message: { Text("已经记录的饮食明细会保留。") }
    }
    private func summary(_ template: MealTemplate) -> NutritionSummary {
        NutritionSummary(entries: (try? template.entries(servings: 1, meal: .lunch, date: date)) ?? [])
    }
}

struct MealTemplateDetailView: View {
    @Environment(JournalStore.self) private var journal
    let templateID: UUID
    let date: Date
    @State private var editing: MealTemplate?
    @State private var recording = false
    private var template: MealTemplate? { journal.mealTemplates.first { $0.id == templateID } }
    var body: some View {
        Group {
            if let template {
                List {
                    Section {
                        Text(template.name).font(.title2.bold())
                        Text("每份包含下方全部条目，沿用保存时的营养快照。").font(.subheadline).foregroundStyle(.secondary)
                        if !template.notes.isEmpty { DisclosureGroup("组合备注") { Text(template.notes) } }
                    }
                    Section("一份的营养") { NutritionSummaryView(summary: NutritionSummary(entries: (try? template.entries(servings: 1, meal: .lunch, date: date)) ?? [])) }
                    Section("一份的内容") {
                        ForEach(template.items.sorted { $0.order < $1.order }) { item in MealItemLabel(item: item) }
                    }
                    Section {
                        Button("编辑组合") { editing = template }.accessibilityIdentifier("mealTemplate.edit")
                        Button("复制为新组合") { editing = template.copied() }.accessibilityIdentifier("mealTemplate.copy")
                    }
                    JournalErrorNotice()
                }.safeAreaInset(edge: .bottom) {
                    Button("记录这份组合", systemImage: "plus") { recording = true }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("mealTemplate.record")
                        .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
                }
                .sheet(isPresented: $recording) { NavigationStack { MealRecordView(template: template, date: date) } }
            } else { ContentUnavailableView("组合已删除", systemImage: "fork.knife", description: Text("已经记录的饮食明细不受影响。")) }
        }.navigationTitle("组合详情").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .sheet(item: $editing) { value in NavigationStack { MealTemplateEditorView(draft: value) } }
    }
}

struct MealItemLabel: View {
    let item: MealTemplateItem
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name.isEmpty ? "快速热量" : item.name).font(.headline)
            Text("\(item.quantity.formatted()) \(item.unitName) · \(item.nutrients.energyKcal.map { $0.formatted() } ?? "未知") kcal").font(.caption).foregroundStyle(.secondary)
            if item.food == nil { Text("宏量营养素按已知资料保留").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct MealTemplateEditorView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MealTemplate
    @State private var selection: MealItemPresentation?
    @State private var selectionReady = true
    @State private var error: String?
    private enum Field: Hashable { case name, notes }
    @FocusState private var focused: Field?
    init(draft: MealTemplate) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("组合名称", text: $draft.name).focused($focused, equals: .name).accessibilityIdentifier("mealTemplate.name")
                    Button { draft.name = ""; focused = .name } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
                        .buttonStyle(.borderless).accessibilityLabel("清空组合名称").accessibilityIdentifier("mealTemplate.clearName")
                }
                TextField("备注（可选）", text: $draft.notes, axis: .vertical).focused($focused, equals: .notes)
                Text("这里只保存组合。要计入饮食日记，请在保存后选择「记录这份组合」。").font(.caption).foregroundStyle(.secondary)
            }
            Section("一份的内容 · \(draft.items.count)/50") {
                ForEach(draft.items) { item in
                    HStack(alignment: .top) {
                        Button { present(.edit(item)) } label: { MealItemLabel(item: item) }.buttonStyle(.plain)
                            .accessibilityIdentifier("mealTemplate.item.\(item.name)")
                        Spacer()
                        Menu {
                            Button("修改份量") { present(.edit(item)) }
                            Button("上移") { move(item.id, offset: -1) }.disabled(draft.items.first?.id == item.id)
                            Button("下移") { move(item.id, offset: 1) }.disabled(draft.items.last?.id == item.id)
                            Button("移除", role: .destructive) { draft.items.removeAll { $0.id == item.id } }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                            .accessibilityLabel("\(item.name)的操作")
                    }
                }.onDelete { draft.items.remove(atOffsets: $0) }
                Button("添加食物", systemImage: "plus") { present(.food) }.disabled(draft.items.count >= 50 || !selectionReady).accessibilityIdentifier("mealTemplate.addFood")
                Button("加入快速热量", systemImage: "bolt") { present(.quick) }.disabled(draft.items.count >= 50 || !selectionReady).accessibilityIdentifier("mealTemplate.addQuick")
            }
            if !draft.items.isEmpty {
                Section("一份的预览") {
                    NutritionSummaryView(summary: NutritionSummary(entries: draft.items.map { $0.entry(servings: 1, meal: .lunch, date: Date()) }))
                }
            }
            if let error { Section { Text(error).accessibilityIdentifier("mealTemplate.error") } }
            JournalErrorNotice()
        }.disabled(journal.busy).navigationTitle("编辑组合餐").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(journal.busy || draft.items.isEmpty).accessibilityIdentifier("mealTemplate.save") }
            }
            .safeAreaInset(edge: .bottom) { if focused != nil { HStack { Spacer(); Button("完成输入") { focused = nil }.frame(minHeight: 44).accessibilityIdentifier("mealTemplate.keyboardDone") }.padding(.horizontal).background(.bar) } }
            .sheet(item: $selection, onDismiss: { selectionReady = true }) { destination in NavigationStack {
                switch destination {
                case .food:
                    FoodSearchView(meal: .lunch, date: Date(), onDraft: { append($0) }) { selection = nil }
                case .quick:
                    QuickCaloriesView(date: Date(), onDraft: { append($0) })
                case .edit(let item):
                    MealItemEditorView(item: item) { updated in
                        if let index = draft.items.firstIndex(where: { $0.id == updated.id }) { draft.items[index] = updated }
                        selection = nil
                    }
                }
            } }
    }
    private func append(_ entry: DietEntry) {
        guard draft.items.count < 50 else { return }
        draft.items.append(MealTemplateItem(entry: entry, order: draft.items.count))
    }
    private func present(_ destination: MealItemPresentation) {
        guard selectionReady else { return }
        selectionReady = false; selection = destination
    }
    private func move(_ id: UUID, offset: Int) {
        guard let index = draft.items.firstIndex(where: { $0.id == id }), draft.items.indices.contains(index + offset) else { return }
        draft.items.swapAt(index, index + offset)
    }
    private func save() {
        do {
            try draft.validate()
            let value = draft
            Task { if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in try await repository.saveMealTemplate(value, catalog: catalog) }) != nil { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}

private enum MealItemPresentation: Identifiable {
    case food, quick, edit(MealTemplateItem)
    var id: String { switch self { case .food: "food"; case .quick: "quick"; case .edit(let v): v.id.uuidString } }
}

private struct MealItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let item: MealTemplateItem
    let onSave: (MealTemplateItem) -> Void
    @State private var quantity: String
    @State private var error: String?
    @FocusState private var focused: Bool
    init(item: MealTemplateItem, onSave: @escaping (MealTemplateItem) -> Void) {
        self.item = item; self.onSave = onSave; _quantity = State(initialValue: numeric(item.quantity))
    }
    var body: some View {
        Form {
            Text(item.name.isEmpty ? "快速热量" : item.name).font(.headline)
            LabeledContent("数量（\(item.unitName)）") { TextField("数量", text: $quantity).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("mealItem.quantity") }
            Text("以这项保存的快照同比调整，不重新读取目录营养。").font(.caption).foregroundStyle(.secondary)
            if let value = try? updated() { NutritionSummaryView(summary: NutritionSummary(entries: [value.entry(servings: 1, meal: .lunch, date: Date())])) }
            if let error { Text(error).accessibilityIdentifier("mealItem.error") }
        }.navigationTitle("组合中的份量").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { do { onSave(try updated()) } catch { self.error = error.localizedDescription } }.accessibilityIdentifier("mealItem.save") }
            }
            .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("mealItem.keyboardDone") }.padding(.horizontal).background(.bar) } }
    }
    private func updated() throws -> MealTemplateItem {
        guard let amount = try TrainingTargetInput.decimal(quantity) else { throw DataProblem.invalid("食用数量") }
        try DomainValidation.number(amount, min: 0.000001, max: 100_000)
        let ratio = amount / item.quantity
        var value = MealTemplateItem(entry: item.entry(servings: ratio, meal: .lunch, date: Date()), order: item.order)
        value.id = item.id; try value.validate(); return value
    }
}

struct MealRecordView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    let template: MealTemplate
    @State private var date: Date
    @State private var meal = Meal.lunch
    @State private var servings = "1"
    @State private var prepared: [DietEntry]?
    @State private var error: String?
    @FocusState private var focused: Bool
    init(template: MealTemplate, date: Date) { self.template = template; _date = State(initialValue: date) }
    var body: some View {
        Form {
            Section {
                Text(template.name).font(.headline)
                LabeledContent("份数") { TextField("份数", text: $servings).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("mealRecord.servings") }
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("mealRecord.error") }
                ViewThatFits(in: .horizontal) {
                    HStack { servingButtons }
                    VStack(alignment: .leading) { servingButtons }
                }
                Picker("餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("mealRecord.meal")
                RecordDatePicker(title: "食用时间", selection: $date)
                Text("一份包含组合中的全部食品，保存后成为可独立编辑的明细。").font(.caption).foregroundStyle(.secondary)
            }
            if let entries = try? entries() {
                Section("本次营养预览") { NutritionSummaryView(summary: NutritionSummary(entries: entries)) }
                Section("本次明细") { ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in MealItemLabel(item: MealTemplateItem(entry: entry, order: index)) } }
            }
            JournalErrorNotice()
        }.disabled(journal.busy).navigationTitle("记录组合餐").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(journal.busy) } }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("mealRecord.keyboardDone") } }
                    Button("记入饮食日记", systemImage: "checkmark") { save() }.buttonStyle(PrimaryButtonStyle()).disabled(journal.busy).accessibilityIdentifier("mealRecord.save")
                }.padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
            }
            .onChange(of: servings) { _, _ in prepared = nil }.onChange(of: meal) { _, _ in prepared = nil }.onChange(of: date) { _, _ in prepared = nil }
    }
    private var servingButtons: some View {
        ForEach(["0.5","1","2"], id: \.self) { amount in Button("\(amount) 份") { servings = amount }.buttonStyle(.bordered).accessibilityIdentifier("mealRecord.servings.\(amount)") }
    }
    private func entries() throws -> [DietEntry] {
        guard let number = try TrainingTargetInput.decimal(servings) else { throw DataProblem.invalid("组合份数") }
        return try template.entries(servings: number, meal: meal, date: date)
    }
    private func save() {
        focused = false
        do {
            let values = try prepared ?? entries(); prepared = values
            Task { if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in try await repository.recordMeal(values, catalog: catalog) }) != nil { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}
