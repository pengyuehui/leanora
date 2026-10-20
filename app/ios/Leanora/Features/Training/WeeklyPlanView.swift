import SwiftUI

struct WeeklyPlanView: View {
    @Environment(TrainingStore.self) private var training
    @State private var date = Date()
    @State private var moving: PlannedOccurrence?
    @State private var opened: WorkoutSession?
    private var day: String { RecordMoment(date).localDate }
    var body: some View {
        List {
            TrainingErrorNotice()
            Section {
                DatePicker("查看日期", selection: $date, displayedComponents: .date).accessibilityIdentifier("weekly.date")
                HStack {
                    Button("前一天") { shift(-1) }.accessibilityIdentifier("weekly.previous")
                    Spacer()
                    Button("今天") { date = Date() }.accessibilityIdentifier("weekly.today")
                    Spacer()
                    Button("后一天") { shift(1) }.accessibilityIdentifier("weekly.next")
                }.buttonStyle(.borderless).frame(minHeight: 44)
                Text(day).accessibilityIdentifier("weekly.selectedDate")
            }
            Section("当天安排") {
                if training.occurrences(on: day).isEmpty { Text("当天没有安排。可在下面编辑模板的每周安排。").foregroundStyle(.secondary).accessibilityIdentifier("weekly.empty") }
                ForEach(training.occurrences(on: day)) { occurrence in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(occurrence.template.name).font(.headline)
                        if occurrence.isMoved { Text("从 \(occurrence.originDate) 移至当天").font(.subheadline).foregroundStyle(.secondary) }
                        if training.isStarted(occurrence) { Label("这次安排已开始", systemImage: "checkmark.circle") }
                        else {
                            Button("开始当天训练") { Task { opened = await training.start(occurrence.template, origin: occurrence.originDate) } }
                                .disabled(day != RecordMoment().localDate || training.busy || occurrence.template.items.isEmpty).accessibilityIdentifier("weekly.start.\(occurrence.template.name)")
                            Button("仅改这一次日期") { moving = occurrence }.accessibilityIdentifier("weekly.move.\(occurrence.template.name)")
                        }
                    }.buttonStyle(.borderless).padding(.vertical, 6)
                }
            }
            Section("每周安排 · 编辑模板") {
                ForEach(training.templates) { template in
                    NavigationLink { TemplateDetailView(templateID: template.id) } label: {
                        VStack(alignment: .leading, spacing: 5) { Text(template.name); Text(weekdaySummary(template.scheduledWeekdays)).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
                Text("每周安排跟随模板；单次改期单独保存，不改变下周。只能开始今天的安排。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("周计划").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .sheet(item: $moving) { occurrence in NavigationStack { RescheduleTrainingView(occurrence: occurrence) { date = $0 } } }
        .sheet(item: $opened) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
    }
    private func shift(_ days: Int) { date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date }
}

struct RescheduleTrainingView: View {
    let occurrence: PlannedOccurrence
    let onSave: (Date) -> Void
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    var body: some View {
        Form {
            TrainingErrorNotice()
            Section {
                Text(occurrence.template.name).font(.headline)
                Text("原安排：\(occurrence.originDate)")
                DatePicker("移至日期", selection: $date, displayedComponents: .date)
                Button("移到明天") { date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }.accessibilityIdentifier("weekly.moveTomorrow")
                Text("只更改这一次安排；模板的每周日期保持不变。").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("单次改期").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存改期") {
                    let destination = RecordMoment(date).localDate, selected = date
                    Task {
                        if await training.run({ [repository = training.repository] in try await repository.rescheduleTraining(templateID: occurrence.template.id, originDate: occurrence.originDate, destinationDate: destination, timeZoneID: TimeZone.current.identifier) }) != nil {
                            onSave(selected); dismiss()
                        }
                    }
                }.disabled(training.busy).accessibilityIdentifier("weekly.saveMove")
            }
        }
        .task {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
            date = formatter.date(from: occurrence.date) ?? Date()
        }
    }
}
