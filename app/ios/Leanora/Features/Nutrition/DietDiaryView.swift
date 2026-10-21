import SwiftUI

struct DietDiaryView: View {
    @Environment(JournalStore.self) private var journal
    @State private var date = Date()
    @State private var presented: DietPresentation?
    @State private var presentationReady = true
    @State private var removing: DietEntry?
    var day: String { RecordMoment(date).localDate }
    var body: some View {
        List {
            Section {
                Text("饮食记录").font(.headline).accessibilityIdentifier("screen.nutrition")
                RecordDatePicker(title: "日记日期", selection: $date, components: .date).accessibilityIdentifier("diet.date")
                HStack {
                    Button { shiftDay(-1) } label: { Label("前一天", systemImage: "chevron.left") }.frame(minHeight: 44).accessibilityIdentifier("diet.previousDay")
                    Spacer()
                    Button("回到今天") { date = Date() }.frame(minHeight: 44).accessibilityIdentifier("diet.today")
                    Spacer()
                    Button { shiftDay(1) } label: { Label("后一天", systemImage: "chevron.right") }.frame(minHeight: 44).accessibilityIdentifier("diet.nextDay")
                }.buttonStyle(.borderless)
            }
            Section("本日营养") { NutritionSummaryView(summary: NutritionSummary(entries: journal.entries, on: day), goal: NutritionCalculator.goal(on: day, goals: journal.goals)) }
            JournalErrorNotice()
            Section {
                Button("快速记热量") { present(.quick) }.disabled(!presentationReady).accessibilityIdentifier("diet.quick")
                Button("复制历史餐次") { present(.copy) }.disabled(!presentationReady).accessibilityIdentifier("diet.copy")
            }
            ForEach(Meal.allCases, id: \.self) { meal in
                Section {
                    let entries = journal.entries.filter { $0.occurred.localDate == day && $0.meal == meal }.sorted { $0.occurred.instant < $1.occurred.instant }
                    ForEach(entries) { entry in
                        Button { present(.edit(entry)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.name.isEmpty ? "快速热量" : entry.name).font(.headline)
                                Text("\(entry.quantity.formatted()) \(entry.unitName) · \(entry.nutrients.energyKcal.map { $0.formatted() } ?? "未知") kcal").font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }.disabled(!presentationReady).accessibilityIdentifier("diet.entry.\(entry.name.isEmpty ? "快速热量" : entry.name)")
                            .swipeActions { Button("删除", role: .destructive) { removing = entry } }
                    }
                    if entries.isEmpty { Text("还没有记录").foregroundStyle(.secondary) }
                    else { Text("本餐已知热量：\(NutritionSummary(entries: entries).energy.text) kcal").font(.caption) }
                    Button { present(.food(meal)) } label: { Label("添加\(meal.title)", systemImage: "plus") }.disabled(!presentationReady).accessibilityIdentifier("diet.add.\(meal.rawValue)")
                } header: { Text(meal.title) }
            }
        }
        .navigationTitle("饮食日记")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(Meal.allCases) { meal in Button("添加\(meal.title)") { present(.food(meal)) } }
                    Button("快速记热量") { present(.quick) }.accessibilityIdentifier("diet.menuQuick")
                    Button("复制历史餐次") { present(.copy) }
                } label: { Label("记录", systemImage: "plus") }.accessibilityIdentifier("diet.addMenu").disabled(!presentationReady)
            }
        }
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .refreshable { await journal.refresh() }
        .task { await journal.refresh() }
        .sheet(item: $presented, onDismiss: { presentationReady = true }) { destination in NavigationStack {
            switch destination {
            case .food(let meal): FoodSearchView(meal: meal, date: date) { presented = nil }
            case .quick: QuickCaloriesView(date: date)
            case .copy: MealCopyView(destination: date)
            case .edit(let entry):
                if let snapshot = entry.food {
                    let food = Food(stamp: RecordStamp(id: snapshot.foodID, revision: snapshot.revision), name: snapshot.name, nutrientsPer100Grams: snapshot.nutrientsPer100Grams, source: snapshot.source)
                    FoodPortionView(food: food, meal: entry.meal, date: entry.occurred.instant, existing: entry) { presented = nil }
                } else { QuickCaloriesView(date: entry.occurred.instant, existing: entry) }
            }
        } }
        .confirmationDialog("删除这条饮食记录？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("确认删除", role: .destructive) { if let removing { Task {
                _ = await journal.run { [repository = journal.repository] in try await repository.deleteDiet(removing.id, revision: removing.stamp.revision) }; self.removing = nil
            } } }
            Button("同时删除健康副本", role: .destructive) { if let removing { Task {
                _ = await journal.run { [repository = journal.repository] in try await repository.deleteDiet(removing.id, revision: removing.stamp.revision, deleteHealthCopies: true) }; self.removing = nil
            } } }
        } message: { Text("「确认删除」保留健康中的副本。其他来源的健康数据不受影响。") }
    }
    private func present(_ destination: DietPresentation) {
        guard presentationReady else { return }
        presentationReady = false; presented = destination
    }
    private func shiftDay(_ offset: Int) { date = Calendar.current.date(byAdding: .day, value: offset, to: date) ?? date }
}

private enum DietPresentation: Identifiable {
    case food(Meal), quick, copy, edit(DietEntry)
    var id: String {
        switch self {
        case .food(let meal): "food:\(meal.rawValue)"
        case .quick: "quick"
        case .copy: "copy"
        case .edit(let entry): "edit:\(entry.id)"
        }
    }
}

extension Meal: Identifiable { var id: String { rawValue } }

struct JournalErrorNotice: View {
    @Environment(JournalStore.self) private var journal
    var body: some View { if let error = journal.error { Section { Label(error, systemImage: "exclamationmark.triangle").accessibilityIdentifier("journal.error") } } }
}

struct NutritionSummaryView: View {
    let summary: NutritionSummary
    var goal: NutritionGoal?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(summary.energy.text).font(.largeTitle.bold().monospacedDigit())
            Text("kcal 已知热量").font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("nutrition.energy")
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) { nutrient("蛋白质", summary.protein); nutrient("碳水化合物", summary.carbohydrate); nutrient("脂肪", summary.fat) }
            VStack(alignment: .leading, spacing: 10) { nutrient("蛋白质", summary.protein); nutrient("碳水化合物", summary.carbohydrate); nutrient("脂肪", summary.fat) }
        }
        if let target = goal?.nutrients.energyKcal {
            LabeledContent("当日热量目标", value: "\(target.formatted()) kcal").accessibilityIdentifier("nutrition.goal")
            if let energy = summary.energy.known {
                Text("按已知热量计算，\(energy > target ? "超过" : "距离")目标 \(abs(target - energy).formatted()) kcal\(summary.energy.missing > 0 ? "；仍有热量缺失，不能判定达标" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else { Text("当日未设置热量目标").font(.caption).foregroundStyle(.secondary) }
        if summary.count == 0 { Text("尚无记录，不代表零摄入。").font(.caption).foregroundStyle(.secondary) }
        else if [summary.energy, summary.protein, summary.carbohydrate, summary.fat].contains(where: { $0.missing > 0 }) {
            Text("部分营养素未知，合计只包含已知值；快速热量不推算宏量营养素。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func nutrient(_ name: String, _ value: NutrientTotal) -> some View {
        let amount = value.known?.formatted(.number.precision(.fractionLength(0...1)))
        return VStack(alignment: .leading, spacing: 4) { Text(name).font(.caption).foregroundStyle(.secondary); Text(amount.map { "\($0) g" } ?? "未知").font(.subheadline.weight(.semibold)).monospacedDigit() }
            .accessibilityElement(children: .ignore).accessibilityLabel("\(name)，\(value.text) g")
    }
}

struct MealCopyView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var source = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var meal = Meal.breakfast
    @State private var targetMeal = Meal.breakfast
    @State var destination: Date
    var body: some View {
        Form {
            RecordDatePicker(title: "来源日期", selection: $source, components: .date)
            Button("来源选择今天") { source = Date() }.accessibilityIdentifier("diet.copyToday")
            Picker("来源餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.title).tag($0) } }
            RecordDatePicker(title: "目标时间", selection: $destination)
            Picker("目标餐次", selection: $targetMeal) { ForEach(Meal.allCases) { Text($0.title).tag($0) } }
            Text("复制后生成独立记录，保留当时的营养快照。")
            JournalErrorNotice()
        }.navigationTitle("复制历史餐次").toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("复制") {
                    let day = RecordMoment(source).localDate, from = meal, to = targetMeal, date = destination
                    Task { if await journal.run({ [repository = journal.repository] in try await repository.copyMeal(from: day, meal: from, to: date, destinationMeal: to) }) != nil { dismiss() } }
                }.disabled(journal.busy).accessibilityIdentifier("diet.confirmCopy") }
            }
    }
}
