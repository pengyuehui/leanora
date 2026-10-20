import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(TrainingStore.self) private var training
    @Environment(AppPreferences.self) private var preferences
    @State private var end = Date()
    @State private var days = 7
    @State private var metric = BodyMetric.weightKg
    var through: String { RecordMoment(end).localDate }
    var from: String { RecordMoment(Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end).localDate }
    var body: some View {
        List {
            Section {
                Text("给变化一点时间。").font(.title2).accessibilityIdentifier("screen.trends")
                NavigationLink("身体记录与测量") { BodyMeasurementView() }.accessibilityIdentifier("trends.body")
                NavigationLink("训练历史") { WorkoutHistoryView() }
                RecordDatePicker(title: "截至日期", selection: $end, components: .date)
                Picker("统计范围", selection: $days) { Text("最近 7 天").tag(7); Text("最近 30 天").tag(30) }.pickerStyle(.segmented)
            }
            let summary = TrainingSummary(sessions: training.sessions, from: from, through: through)
            Section("训练 · \(from) 至 \(through)") {
                LabeledContent("完成训练", value: "\(summary.workouts) 次")
                LabeledContent("有效时长", value: "\(Int(summary.activeSeconds / 60)) 分钟")
                LabeledContent("完成组数（含各组类型）", value: "\(summary.completedSets)")
                LabeledContent("正式负重容量", value: "\(summary.volumeKg.formatted()) kg·次").accessibilityIdentifier("trends.volume")
                Text("容量只含已完成的外部负重正式组；训练按开始时当地日期计入一次。热身、自重、辅助及计时不折算为负重容量。").font(.caption).foregroundStyle(.secondary)
                let points = trainingPoints
                if !points.isEmpty {
                    Chart(points) { point in BarMark(x: .value("日期", point.day), y: .value("容量 kg·次", point.value)).foregroundStyle(LeanoraTheme.accent) }
                        .frame(height: 180).accessibilityLabel("逐日正式负重容量")
                }
                if summary.timedSeconds > 0 { LabeledContent("计时动作时长", value: "\(Int(summary.timedSeconds)) 秒") }
                if summary.distanceMeters > 0 { LabeledContent("有氧实际距离", value: "\(summary.distanceMeters.formatted()) m") }
                if summary.bodyweightRepetitions > 0 { LabeledContent("自重动作完成次数", value: "\(summary.bodyweightRepetitions) 次") }
                if summary.assistedRepetitions > 0 { LabeledContent("辅助动作完成次数", value: "\(summary.assistedRepetitions) 次") }
            }
            Section("最佳正式组负重 · 所选范围") {
                if summary.personalRecords.isEmpty { Text("尚无符合口径的记录").foregroundStyle(.secondary) }
                ForEach(summary.personalRecords.keys.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                    let kg = summary.personalRecords[id] ?? 0
                    LabeledContent(training.exercise(id)?.name ?? "历史动作", value: "\((kg / (preferences.values.weightUnit == .pounds ? 0.45359237 : 1)).formatted()) \(preferences.values.weightUnit.rawValue)")
                }
                Text("采用正式组最大实际负重，不估算 1RM。编辑或删除来源组后自动重算。").font(.caption)
            }
            Section("身体变化") {
                Picker("测量类型", selection: $metric) { ForEach(BodyMetric.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                let values = BodySummary.dailyLatest(journal.measurements, metric: metric).filter { $0.occurred.localDate >= from && $0.occurred.localDate <= through }
                if values.isEmpty { Text("本时段没有测量记录").foregroundStyle(.secondary) }
                else {
                    if let latest = values.last { LabeledContent("时段内最近一次", value: bodyValue(latest, pounds: preferences.values.weightUnit == .pounds)) }
                    if let average = BodySummary.average(journal.measurements, metric: metric, from: from, through: through) {
                        Text("日末测量均值：\((average / (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1)).formatted(.number.precision(.fractionLength(0...2)))) \(metric == .bodyFatPercent ? "%" : preferences.values.weightUnit.rawValue)")
                    }
                    Chart(values) { value in
                        LineMark(x: .value("日期", value.occurred.localDate), y: .value(metric.title, value.value / (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1))).foregroundStyle(LeanoraTheme.accent)
                        PointMark(x: .value("日期", value.occurred.localDate), y: .value(metric.title, value.value / (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1))).foregroundStyle(LeanoraTheme.accent)
                    }.frame(height: 180).accessibilityLabel("每日最后一次\(metric.title)趋势")
                }
            }
            Section("饮食热量 · 不自动叠加运动消耗") {
                let points = nutritionPoints
                if points.isEmpty { Text("本时段没有已知热量记录").foregroundStyle(.secondary) }
                else {
                    Chart(points) { point in BarMark(x: .value("日期", point.day), y: .value("已知 kcal", point.value)).foregroundStyle(LeanoraTheme.accent) }.frame(height: 180)
                    ForEach(points) { point in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.day).font(.caption)
                            let daySummary = NutritionSummary(entries: journal.entries, on: point.day)
                            Text("\(daySummary.energy.text) kcal · 蛋白质 \(daySummary.protein.text) g · 碳水 \(daySummary.carbohydrate.text) g · 脂肪 \(daySummary.fat.text) g").font(.subheadline)
                            if let goal = NutritionCalculator.goal(on: point.day, goals: journal.goals)?.nutrients.energyKcal { Text("当日目标 \(goal.formatted()) kcal").font(.caption) }
                        }
                    }
                }
                Text("缺少记录的日期不视为零摄入；未知营养素不会计成零。").font(.caption)
            }
        }
        .navigationTitle("身体与趋势").scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .toolbar(.visible, for: .navigationBar)
        .task { await journal.refresh(); await training.refresh() }
    }
    private var trainingPoints: [TrendPoint] {
        Set(training.sessions.filter { $0.status == .completed && $0.started.localDate >= from && $0.started.localDate <= through }.map { $0.started.localDate }).sorted().map { day in
            TrendPoint(day: day, value: TrainingSummary(sessions: training.sessions, from: day, through: day).volumeKg)
        }
    }
    private var nutritionPoints: [TrendPoint] {
        Set(journal.entries.filter { $0.occurred.localDate >= from && $0.occurred.localDate <= through }.map { $0.occurred.localDate }).sorted().compactMap { day in
            NutritionSummary(entries: journal.entries, on: day).energy.known.map { TrendPoint(day: day, value: $0) }
        }
    }
}
struct TrendPoint: Identifiable { var day: String; var value: Double; var id: String { day } }
