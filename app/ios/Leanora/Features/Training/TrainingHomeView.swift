import SwiftUI

struct TrainingErrorNotice: View {
    @Environment(TrainingStore.self) private var training
    var body: some View {
        if let error = training.error {
            Section { Label(error, systemImage: "exclamationmark.triangle").accessibilityIdentifier("training.error") }
        }
    }
}

struct TrainingHomeView: View {
    @Environment(TrainingStore.self) private var training
    @State private var creating = false
    @State private var opened: WorkoutSession?
    var body: some View {
        List {
            Section {
                Text("训练计划").font(.title2.bold()).accessibilityIdentifier("screen.training")
                if let active = training.active {
                    Button { opened = active } label: { Label("返回进行中的训练：\(active.name)", systemImage: "play.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("training.active")
                }
                NavigationLink { ExerciseLibraryView() } label: { Label("动作库", systemImage: "figure.strengthtraining.traditional") }
                    .accessibilityIdentifier("training.library")
                NavigationLink { WeeklyPlanView() } label: { Label("周计划与单次安排", systemImage: "calendar") }
                    .accessibilityIdentifier("training.weekly")
                NavigationLink { WorkoutHistoryView() } label: { Label("训练历史", systemImage: "clock.arrow.circlepath") }.accessibilityIdentifier("training.history")
            }
            TrainingErrorNotice()
            let today = training.occurrences(on: RecordMoment().localDate)
            if training.active == nil, !today.isEmpty {
                Section("今天的安排") {
                    ForEach(today) { occurrence in
                        Button { Task { opened = await training.start(occurrence.template) } } label: {
                            HStack { VStack(alignment: .leading, spacing: 4) { Text(occurrence.template.name).font(.headline); Text("\(occurrence.template.items.count) 个动作").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "play.circle.fill").font(.title) }.frame(minHeight: 52)
                        }.buttonStyle(.borderless).accessibilityIdentifier("training.today.\(occurrence.template.name)")
                    }
                }
            }
            Section("我的模板") {
                Button { creating = true } label: { Label("新建训练模板", systemImage: "plus") }.accessibilityIdentifier("training.newTemplate")
                if training.templates.isEmpty { Text("先添加动作和计划目标，再安排每周训练。模板可随时调整。").foregroundStyle(.secondary) }
                ForEach(training.templates) { template in
                    NavigationLink { TemplateDetailView(templateID: template.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name).font(.headline)
                            Text("\(template.items.count) 个动作 · \(weekdaySummary(template.scheduledWeekdays))").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }.accessibilityIdentifier("training.template.\(template.name)")
                }
            }
        }
        .navigationTitle("训练").toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .refreshable { await training.refresh() }
        .task { await training.refresh() }
        .sheet(isPresented: $creating) { NavigationStack { TemplateEditorView(template: WorkoutTemplate(name: "")) } }
        .sheet(item: $opened) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
    }
}

let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
func weekdaySummary(_ days: [Int]) -> String {
    let names = days.sorted().compactMap { (1...7).contains($0) ? weekdayNames[$0 - 1] : nil }
    return names.isEmpty ? "未设置周安排" : names.joined(separator: "、")
}

struct TemplateDetailView: View {
    let templateID: UUID
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var deleting = false
    @State private var opened: WorkoutSession?
    private var template: WorkoutTemplate? { training.templates.first { $0.id == templateID } }
    var body: some View {
        List {
            TrainingErrorNotice()
            if let template {
                Section {
                    Text(template.name).font(.title2.weight(.semibold)).accessibilityIdentifier("template.title")
                    Text(weekdaySummary(template.scheduledWeekdays)).foregroundStyle(.secondary)
                    Button { Task { opened = await training.start(template) } } label: { Label("开始训练", systemImage: "play.fill") }
                        .disabled(training.busy || template.items.isEmpty).accessibilityIdentifier("template.start")
                    if template.items.isEmpty { Text("空模板还不能开始，请先添加动作。").foregroundStyle(.secondary) }
                }
                Section("计划动作") {
                    ForEach(template.items.sorted { $0.order < $1.order }) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(training.exercise(item.exerciseID)?.name ?? "动作不可用").font(.headline)
                            Text("\(item.plannedSets) 组 · 休息 \(item.restSeconds.formatted()) 秒").foregroundStyle(.secondary)
                            if training.exercise(item.exerciseID)?.isArchived == true { Label("此动作已归档，开始前需替换或恢复", systemImage: "archivebox") }
                        }
                    }
                }
                if !template.notes.isEmpty { Section("备注") { Text(template.notes) } }
                Section {
                    Button("编辑模板") { editing = true }.accessibilityIdentifier("template.edit")
                    Button("复制模板") {
                        Task { _ = await training.run { [repository = training.repository] in try await repository.copyTrainingTemplate(templateID) } }
                    }.disabled(training.busy).accessibilityIdentifier("template.copy")
                    Text("副本使用新的项目 ID，不复制每周安排。").font(.footnote).foregroundStyle(.secondary)
                    Button("删除模板", role: .destructive) { deleting = true }.accessibilityIdentifier("template.delete")
                }
            } else { ContentUnavailableView("模板已移除", systemImage: "doc") }
        }
        .navigationTitle("训练模板").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .sheet(isPresented: $editing) { if let template { NavigationStack { TemplateEditorView(template: template) } } }
        .sheet(item: $opened) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
        .confirmationDialog("删除此模板？", isPresented: $deleting, titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                if let template { Task { if await training.run({ [repository = training.repository] in try await repository.deleteTrainingTemplate(template) }) != nil { dismiss() } } }
            }
        } message: { Text("模板与未来每周安排将移除，已开始的训练快照会保留。") }
    }
}

struct WorkoutReadyView: View {
    let sessionID: UUID
    var body: some View { ActiveWorkoutView(sessionID: sessionID) }
}
