import SwiftUI

struct DietDayCopyView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var source: Date
    @State private var destination: Date
    @State private var meals = Set(Meal.allCases)
    @State private var prepared: [DietEntry]?
    @State private var error: String?
    private var sourceDay: String { RecordMoment(source).localDate }

    init(destination: Date, source: Date? = nil) {
        _destination = State(initialValue: destination)
        _source = State(initialValue: source ?? Calendar.current.date(byAdding: .day, value: -1, to: destination) ?? destination)
    }

    var body: some View {
        List {
            Section {
                Text("把常吃的一天，再记一次").font(.title2.bold())
                Text("选择有记录的餐次，先检查预览，再保存到目标日期。").foregroundStyle(.secondary)
                RecordDatePicker(title: "来源日期", selection: $source, components: .date).accessibilityIdentifier("dayCopy.source")
                RecordDatePicker(title: "目标日期", selection: $destination, components: .date).accessibilityIdentifier("dayCopy.destination")
            }
            Section("选择餐次") {
                ForEach(Meal.allCases) { meal in
                    let count = journal.entries.filter { $0.occurred.localDate == sourceDay && $0.meal == meal }.count
                    Toggle(isOn: Binding(get: { meals.contains(meal) }, set: { if $0 { meals.insert(meal) } else { meals.remove(meal) } })) {
                        Text("\(meal.title) · \(count) 项")
                    }.accessibilityIdentifier("dayCopy.meal.\(meal.rawValue)")
                }
            }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle").accessibilityIdentifier("dayCopy.error") } }
            JournalErrorNotice()
            if let prepared {
                Section("复制预览 · \(prepared.count) 项") {
                    NutritionSummaryView(summary: NutritionSummary(entries: prepared))
                }
                ForEach(Meal.allCases) { meal in
                    let items = prepared.filter { $0.meal == meal }
                    if !items.isEmpty {
                        Section(meal.title) {
                            ForEach(items) { entry in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.name.isEmpty ? "快速热量" : entry.name).font(.headline)
                                    Text("\(entry.quantity.formatted()) \(entry.unitName) · \(entry.nutrients.energyKcal.map { $0.formatted() } ?? "未知") kcal")
                                    Text(entry.occurred.instant, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                                }.accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
            Section("保存规则") {
                Text("保留原记录的份量、备注和营养快照。未知值继续未知；按原本地钟点映射到目标日，夏令时缺失钟点顺延。每次最多 200 项。")
                Text("目标日期已有的记录会保留；确认将新增独立记录。仅预览或取消不会写入日记或 Apple Health。")
                let existing = journal.entries.filter { $0.occurred.localDate == RecordMoment(destination).localDate }.count
                Text("目标日当前已有 \(existing) 项。请确认没有重复记录。").font(.caption).foregroundStyle(.secondary)
            }.font(.footnote)
        }
        .disabled(journal.busy)
        .navigationTitle("复制整日饮食").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(journal.busy).accessibilityIdentifier("dayCopy.cancel") } }
        .safeAreaInset(edge: .bottom) {
            Button {
                if let prepared {
                    Task {
                        if await journal.run({ [repository = journal.repository, catalog = journal.catalog] in
                            try await repository.recordDietDayCopy(prepared, catalog: catalog)
                        }) != nil { dismiss() }
                    }
                } else {
                    do {
                        prepared = try DietDayCopy.prepare(entries: journal.entries, sourceDay: sourceDay, meals: meals, destination: destination)
                        error = nil; journal.error = nil
                    } catch { self.error = error.localizedDescription }
                }
            } label: { Label(prepared == nil ? "预览复制" : "确认新增 \(prepared?.count ?? 0) 项", systemImage: prepared == nil ? "doc.on.doc" : "checkmark") }
                .buttonStyle(PrimaryButtonStyle()).disabled(journal.busy).accessibilityIdentifier("dayCopy.confirm")
                .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
        }
        .onChange(of: source) { resetPreview() }
        .onChange(of: destination) { resetPreview() }
        .onChange(of: meals) { resetPreview() }
        .task { await journal.refresh() }
    }
    private func resetPreview() { prepared = nil; error = nil; journal.error = nil }
}
