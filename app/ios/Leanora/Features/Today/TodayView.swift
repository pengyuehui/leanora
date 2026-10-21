import SwiftUI

struct TodayView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(TrainingStore.self) private var training
    @Environment(JournalStore.self) private var journal
    @Environment(DataStoreController.self) private var store
    @State private var opened: WorkoutSession?
    @Binding var selected: AppTab
    private var day: String { RecordMoment().localDate }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("今天").font(.largeTitle.bold()).accessibilityIdentifier("screen.today")
                    Spacer()
                    Text(Date.now, format: .dateTime.month().day().weekday()).font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Label("今日训练", systemImage: "dumbbell").font(.headline); Spacer(); Button("计划") { selected = .training }.frame(minHeight: 44) }
                    if let active = training.active {
                        Text(active.name).font(.title2.bold())
                        let sets = active.exercises.flatMap(\.sets)
                        Text("\(sets.filter { $0.completedAt != nil }.count) / \(sets.count) 组已完成 · \(active.status == .paused ? "已暂停" : "进行中")").font(.subheadline).foregroundStyle(.secondary)
                        Button { opened = active } label: { Label("返回进行中的训练", systemImage: "play.fill") }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("today.active")
                    } else if let occurrence = training.occurrences(on: day).first {
                        Text(occurrence.template.name).font(.title2.bold())
                        Text("\(occurrence.template.items.count) 个动作 · 按计划逐组记录").font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { opened = await training.start(occurrence.template) } } label: { Label("开始今日训练", systemImage: "play.fill") }
                            .buttonStyle(PrimaryButtonStyle()).disabled(training.busy).accessibilityIdentifier("today.start")
                    } else {
                        Text("今天没有安排").font(.title2.bold())
                        Text("从自己的模板开始，或调整本周安排。").font(.subheadline).foregroundStyle(.secondary)
                        Button { selected = .training } label: { Label("选择训练模板", systemImage: "plus") }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("today.training")
                    }
                    let summary = TrainingSummary(sessions: training.sessions, from: day, through: day)
                    if summary.workouts > 0 { Label("今天已完成 \(summary.workouts) 次训练", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(.secondary) }
                }.padding(20).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Label("饮食记录", systemImage: "fork.knife").font(.headline); Spacer(); Button("记一餐") { selected = .nutrition }.frame(minHeight: 44).accessibilityIdentifier("today.nutrition") }
                    NutritionSummaryView(summary: NutritionSummary(entries: journal.entries, on: day), goal: NutritionCalculator.goal(on: day, goals: journal.goals))
                }.padding(20).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("最近体重").font(.subheadline).foregroundStyle(.secondary)
                        Text(journal.measurements.filter { $0.metric == .weightKg }.max(by: { $0.occurred.instant < $1.occurred.instant }).map { bodyValue($0, pounds: preferences.values.weightUnit == .pounds) } ?? "还没有记录").font(.title3.bold()).monospacedDigit()
                    }
                    Spacer()
                    NavigationLink { BodyMeasurementView() } label: { Label("记录", systemImage: "plus") }.frame(minHeight: 44).accessibilityIdentifier("today.body")
                }
                Button { selected = .trends } label: { HStack { Label("查看训练与身体趋势", systemImage: "chart.xyaxis.line"); Spacer(); Image(systemName: "chevron.right") }.frame(minHeight: 44) }.accessibilityIdentifier("today.trends")
                if let activity = store.healthSync?.activity, store.healthSync?.configuration.readActivity == true {
                    HStack { Label(activity.steps.map { "\(Int($0)) 步" } ?? "暂无可读步数", systemImage: "figure.walk"); Spacer(); Text("Apple Health").foregroundStyle(.secondary) }.font(.footnote)
                }
            }.padding(20)
        }.background(LeanoraTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .task { await training.refresh(); await journal.refresh() }
            .refreshable { await training.refresh(); await journal.refresh(); await store.healthSync?.sync() }
            .sheet(item: $opened) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
    }
}
