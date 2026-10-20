import SwiftUI

struct TodayView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(TrainingStore.self) private var training
    @State private var opened: WorkoutSession?
    @Binding var selected: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionEyebrow(text: Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                        Text("今天，也为自己。")
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("screen.today")
                    }
                    Spacer(minLength: 12)
                    LeanoraMark(size: 44)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("让好习惯，\n慢慢发生。")
                        .font(.system(.title, design: .serif, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("记录不必完美，真实就很好。")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "leaf")
                        Text(training.active == nil ? "按自己的节奏安排今天" : "有一场训练正在进行")
                    }.font(.footnote.weight(.medium)).foregroundStyle(LeanoraTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                if let active = training.active {
                    Button { opened = active } label: { Label("返回进行中的训练", systemImage: "play.circle.fill") }.frame(minHeight: 44).accessibilityIdentifier("today.active")
                }
                if !training.occurrences(on: RecordMoment().localDate).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今天的训练安排").font(.headline)
                        ForEach(training.occurrences(on: RecordMoment().localDate)) { occurrence in
                            Button(occurrence.template.name) { selected = .training }.frame(minHeight: 44)
                        }
                    }
                }
                VStack(spacing: 0) {
                    portal(title: "训练日记", detail: "每一组，都有它的意义。", symbol: "dumbbell", tab: .training)
                    Divider()
                    portal(title: "饮食日记", detail: "从一日三餐，看见日常。", symbol: "fork.knife", tab: .nutrition)
                    Divider()
                    portal(title: "身体与趋势", detail: "给变化一点时间。", symbol: "chart.xyaxis.line", tab: .trends)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(text: "按照你的节奏")
                    HStack {
                        Text("每周训练").foregroundStyle(.secondary)
                        Spacer()
                        Text(preferences.values.weeklyTrainingDays.map { "\($0) 天" } ?? "未设置")
                    }
                    HStack {
                        Text("每日热量目标").foregroundStyle(.secondary)
                        Spacer()
                        Text(preferences.values.dailyEnergyGoal.map { "\($0.formatted()) kcal" } ?? "未设置")
                    }
                    NavigationLink("调整单位与目标") { PreferencesEditorView() }
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }.font(.subheadline)
            }.padding(24)
        }
        .background(LeanoraTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .task { await training.refresh() }
        .sheet(item: $opened) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
    }

    private func portal(title: String, detail: String, symbol: String, tab: AppTab) -> some View {
        Button { selected = tab } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title2).foregroundStyle(LeanoraTheme.accent).frame(width: 32)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
            }.padding(.vertical, 20).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("today.\(tab.rawValue)")
    }
}
