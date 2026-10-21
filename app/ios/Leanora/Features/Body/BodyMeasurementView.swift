import SwiftUI

struct BodyMeasurementView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(AppPreferences.self) private var preferences
    @State private var editor: BodyEditorRoute?
    @State private var removing: BodyMeasurement?
    @State private var metric = BodyMetric.weightKg
    var body: some View {
        List {
            Section {
                Button("记录身体数据") { editor = BodyEditorRoute() }.accessibilityIdentifier("body.add")
                Picker("测量类型", selection: $metric) { ForEach(BodyMetric.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Text("保留同日每次测量；趋势每天采用最后一次测量。体脂以百分比输入，例如 20 代表 20%。").font(.caption).foregroundStyle(.secondary)
            }
            JournalErrorNotice()
            let values = journal.measurements.filter { $0.metric == metric }.sorted { $0.occurred.instant > $1.occurred.instant }
            if values.isEmpty { ContentUnavailableView("还没有\(metric.title)记录", systemImage: "scalemass") }
            ForEach(values) { measurement in
                Button { editor = BodyEditorRoute(measurement: measurement) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bodyValue(measurement, pounds: preferences.values.weightUnit == .pounds)).font(.headline)
                        Text(measurement.occurred.instant, format: .dateTime.year().month().day().hour().minute()).font(.caption)
                        Text(measurement.source.name).font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("body.record")
                    .swipeActions { Button("删除", role: .destructive) { removing = measurement } }
            }
        }.navigationTitle("身体记录")
            .toolbar(.visible, for: .navigationBar)
            .sheet(item: $editor) { route in NavigationStack { BodyMeasurementEditor(original: route.measurement) } }
            .confirmationDialog("删除这次测量？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("确认删除", role: .destructive) { if let removing { Task {
                    _ = await journal.run { [repository = journal.repository] in try await repository.deleteMeasurement(removing.id, revision: removing.stamp.revision) }; self.removing = nil
                } } }
                Button("同时删除健康副本", role: .destructive) { if let removing { Task {
                    _ = await journal.run { [repository = journal.repository] in try await repository.deleteMeasurement(removing.id, revision: removing.stamp.revision, deleteHealthCopies: true) }; self.removing = nil
                } } }
            } message: { Text("「确认删除」保留健康中的副本。其他来源的健康数据不受影响。") }
    }
}

private struct BodyEditorRoute: Identifiable {
    var measurement: BodyMeasurement?
    var id: String { measurement?.id.uuidString ?? "new" }
}

func bodyValue(_ value: BodyMeasurement, pounds: Bool) -> String {
    if value.metric == .bodyFatPercent { return "\(value.value.formatted(.number.precision(.fractionLength(0...2))))%" }
    return "\((value.value / (pounds ? 0.45359237 : 1)).formatted(.number.precision(.fractionLength(0...2)))) \(pounds ? "lb" : "kg")"
}

struct BodyMeasurementEditor: View {
    var original: BodyMeasurement?
    @Environment(JournalStore.self) private var journal
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var metric = BodyMetric.weightKg
    @State private var date = Date()
    @State private var value = ""
    @State private var error: String?
    @State private var confirming = false
    @FocusState private var focused: Bool
    var body: some View {
        Form {
            Section {
                Picker("测量类型", selection: $metric) { ForEach(BodyMetric.allCases, id: \.self) { Text($0.title).tag($0) } }.accessibilityIdentifier("body.metric").disabled(original != nil)
                LabeledContent(metric == .weightKg ? "体重（\(preferences.values.weightUnit.rawValue)）" : "体脂率（%）") { TextField("实际测量值", text: $value).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("body.value") }
                RecordDatePicker(title: "测量时间", selection: $date)
                Text("来源：用户创建。每次新增均保留独立记录。").font(.caption)
            }
            if let error { Text(error).accessibilityIdentifier("body.error") }
            JournalErrorNotice()
        }.navigationTitle(original == nil ? "新增测量" : "编辑测量").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .task { if let original { metric = original.metric; date = original.occurred.instant; value = numeric(original.value / (original.metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1)) } }
            .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("body.keyboardDone") }.padding(.horizontal).background(.bar) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") {
                    if let original, original.occurred.localDate != RecordMoment(date).localDate { confirming = true } else { save() }
                }.disabled(journal.busy).accessibilityIdentifier("body.save") }
            }
            .confirmationDialog("测量将归属新的日期，确认保存？", isPresented: $confirming, titleVisibility: .visible) { Button("确认更改日期") { save() } }
    }
    private func save() {
        do {
            guard let number = try TrainingTargetInput.decimal(value) else { throw DataProblem.invalid("测量值") }
            var measurement = BodyMeasurement(occurred: RecordMoment(date), metric: metric, value: number * (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1))
            if let original { measurement.stamp = original.stamp }
            let draft = measurement
            Task { if await journal.run({ [repository = journal.repository] in try await repository.saveMeasurement(draft) }) != nil { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}
