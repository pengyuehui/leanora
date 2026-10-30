import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(TrainingStore.self) private var training
    @State private var day = Date()
    @State private var allDates = true
    @State private var opened: WorkoutSession?
    var body: some View {
        List {
            Section {
                Toggle("显示所有日期", isOn: $allDates)
                if !allDates { RecordDatePicker(title: "开始日期", selection: $day, components: .date) }
            }
            let sessions = training.sessions.filter { [.completed, .abandoned].contains($0.status) && (allDates || $0.started.localDate == RecordMoment(day).localDate) }.sorted { $0.started.instant > $1.started.instant }
            if sessions.isEmpty { ContentUnavailableView("还没有训练历史", systemImage: "calendar", description: Text("完成或放弃的训练会保存在这里。")) }
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 10) {
                Button { opened = session } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(session.name).font(.headline)
                        Text("\(session.started.localDate) · \(session.status == .completed ? "已完成" : "已放弃") · \(Int(TrainingSummary.activeDuration(session, at: session.endedAt ?? Date()))) 秒")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }.accessibilityIdentifier("history.\(session.name)")
                .buttonStyle(.plain)
                if session.status == .completed {
                    Button { Task { opened = await training.repeatWorkout(session.id) } } label: {
                        Label("再练一次", systemImage: "arrow.clockwise")
                    }.buttonStyle(.borderless).disabled(training.busy).accessibilityIdentifier("history.repeat.\(session.name)")
                    Text("复用已完成组的实际值，重新记录这一轮。").font(.caption).foregroundStyle(.secondary)
                }
                }
            }
            TrainingErrorNotice()
        }
        .navigationTitle("训练历史").accessibilityIdentifier("screen.history")
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $opened) { session in NavigationStack {
            if session.status == .abandoned {
                List { Text(session.name); Text("该训练已放弃，不计入训练次数、容量或 PR。"); Text(session.started.localDate) }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { opened = nil } } }
            } else { ActiveWorkoutView(sessionID: session.id) }
        } }
    }
}
