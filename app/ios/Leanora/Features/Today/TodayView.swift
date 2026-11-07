import SwiftUI

struct TodayView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(TrainingStore.self) private var training
    @Environment(JournalStore.self) private var journal
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var opened: WorkoutSession?
    @Binding var selected: AppTab
    private var day: String { RecordMoment().localDate }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { todayHeading; dateLabel }
                trainingInfo
                HStack { startButton; Spacer(); planLink }
            } else {
                HStack { todayHeading; Spacer(); dateLabel }
                HStack(spacing: 12) { trainingInfo; Spacer(minLength: 4); startButton; planLink }
            }
            Divider()
            if typeSize.isAccessibilitySize {
                nutritionNumbers
                mealButton
                Divider()
                bodyLink
            } else {
                HStack(spacing: 12) { nutritionNumbers; Spacer(); mealButton; bodyLink }
            }
            nutrientDetails
        }.padding(16).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .sheet(item: $opened, onDismiss: { Task { await training.refresh() } }) { session in NavigationStack { WorkoutReadyView(sessionID: session.id) } }
    }
    private var todayHeading: some View {
        Label("今天", systemImage: "calendar").font(.headline).accessibilityIdentifier("screen.today")
    }
    private var dateLabel: some View {
        Text(Date.now, format: .dateTime.month().day().weekday()).font(.caption).foregroundStyle(.secondary)
    }
    private var trainingInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(training.active?.name ?? training.occurrences(on: day).first?.template.name ?? "自由训练").font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if let active = training.active {
                let sets = active.exercises.flatMap(\.sets)
                Text("\(sets.filter { $0.completedAt != nil }.count)/\(sets.count) 组 · \(active.status == .paused ? "已暂停" : "进行中")").font(.caption).foregroundStyle(.secondary)
            } else {
                let summary = TrainingSummary(sessions: training.sessions, from: day, through: day)
                Text(summary.workouts > 0 ? "已完成 \(summary.workouts) 次" : "尚未训练").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var startButton: some View {
        Button {
            Task {
                if let active = training.active { opened = active }
                else if let occurrence = training.occurrences(on: day).first { opened = await training.start(occurrence.template) }
                else { opened = await training.startFree() }
            }
        } label: {
            Label { Text(training.active == nil ? "开始" : "继续") } icon: { Image(systemName: "play.fill").font(.system(size: 20)) }
                .font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44).fixedSize(horizontal: true, vertical: true)
        }.buttonStyle(.borderedProminent).disabled(training.busy).accessibilityIdentifier("today.start")
    }
    private var planLink: some View {
        NavigationLink { TrainingHomeView() } label: { Image(systemName: "list.clipboard").font(.system(size: 22)).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .accessibilityLabel("训练计划与模板").accessibilityIdentifier("today.training")
    }
    private var nutritionNumbers: some View {
        let nutrition = NutritionSummary(entries: journal.entries, on: day)
        return VStack(alignment: .leading, spacing: 3) {
            Text("饮食").font(.caption).foregroundStyle(.secondary)
            Text(nutrition.count == 0 ? "尚未记录" : "\(nutrition.energy.text) kcal").font(.headline).monospacedDigit().accessibilityIdentifier("nutrition.energy")
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var mealButton: some View {
        Button("记一餐", systemImage: "plus") { selected = .nutrition }.frame(minHeight: 44).accessibilityIdentifier("today.nutrition")
    }
    private var nutrientDetails: some View {
        let summary = NutritionSummary(entries: journal.entries, on: day)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 16))
        return VStack(alignment: .leading, spacing: 8) {
            if let goal = NutritionCalculator.goal(on: day, goals: journal.goals)?.nutrients.energyKcal {
                LabeledContent("热量目标", value: "\(goal.formatted()) kcal").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("nutrition.goal")
            }
            if summary.count > 0 {
                layout {
                    nutrient("蛋白质", summary.protein)
                    nutrient("碳水", summary.carbohydrate)
                    nutrient("脂肪", summary.fat)
                }
                if summary.missingFields > 0 { Text("\(summary.missingFields) 个营养字段未知").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
    private func nutrient(_ title: String, _ value: NutrientTotal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(.secondary)
            Text(value.known.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) g" } ?? "未知").fontWeight(.semibold).monospacedDigit()
        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(title)，\(value.text) g")
    }
    private var bodyLink: some View {
        NavigationLink { BodyMeasurementView() } label: {
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                Text("体重").font(.caption).foregroundStyle(.secondary)
                Text(journal.measurements.filter { $0.metric == .weightKg }.max(by: { $0.occurred.instant < $1.occurred.instant }).map { bodyValue($0, pounds: preferences.values.weightUnit == .pounds) } ?? "添加").font(.subheadline.weight(.semibold))
            }.frame(minHeight: 44)
        }.accessibilityIdentifier("today.body")
    }
}
