import SwiftUI
import Charts

enum HistoryCategory: String, CaseIterable, Identifiable {
    case training = "训练", body = "体重体脂", nutrition = "饮食"
    var id: Self { self }
}

struct HistoryHomeView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(TrainingStore.self) private var training
    @Environment(DataStoreController.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selected: AppTab
    @State private var date = Date()
    @State private var mode = "历史"
    @State private var category = HistoryCategory.training
    @State private var choosingDate = false
    @State private var opened: WorkoutSession?
    @State private var copying = false
    private var dates: [JournalCalendarDay] { JournalMonth.days(containing: date) }
    private var day: String { RecordMoment(date).localDate }
    private var review: JournalReview {
        JournalReview(dates: dates.map(\.day), sessions: training.sessions, entries: journal.entries, measurements: journal.measurements)
    }
    var body: some View {
        let records = review
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TodayView(selected: $selected)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) { monthHeader; modePicker }
                } else { ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { monthHeader; Spacer(minLength: 4); modePicker.frame(width: 160) }
                    VStack(alignment: .leading, spacing: 12) { monthHeader; modePicker }
                } }
                if typeSize.isAccessibilitySize { categoryPicker.pickerStyle(.menu).frame(minHeight: 44) }
                else { categoryPicker.pickerStyle(.segmented) }
                if mode == "历史" {
                    calendar(records)
                    if let value = records.days.first(where: { $0.day == day }) { dayDetails(value) }
                } else {
                    HistoryStatisticsView(date: date, category: category)
                }
                TrainingErrorNotice(); JournalErrorNotice()
            }.padding(16)
        }
        .background(LeanoraTheme.canvas).navigationTitle("历史").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink { JournalReviewView() } label: { Label("周回顾", systemImage: "calendar") }
                    NavigationLink { WorkoutHistoryView() } label: { Label("训练历史", systemImage: "dumbbell") }
                    NavigationLink { TrendsView() } label: { Label("完整统计", systemImage: "chart.bar") }
                    NavigationLink { HealthConnectionView() } label: { Label("Apple Health", systemImage: "heart") }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 22)) }.accessibilityLabel("历史选项").accessibilityIdentifier("history.options")
            }
        }
        .task { await training.refresh(); await journal.refresh() }
        .refreshable { await training.refresh(); await journal.refresh(); await store.healthSync?.sync() }
        .sheet(isPresented: $choosingDate) {
            NavigationStack {
                DatePicker("查看日期", selection: $date, displayedComponents: .date).datePickerStyle(.graphical).padding()
                    .navigationTitle("选择日期").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { choosingDate = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $copying) { NavigationStack { DietDayCopyView(destination: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date, source: date) } }
        .sheet(item: $opened, onDismiss: { Task { await training.refresh() } }) { session in
            NavigationStack {
                if session.status == .abandoned {
                    List { Text(session.name); Text("已放弃 · 不计入训练统计") }
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { opened = nil } } }
                } else { ActiveWorkoutView(sessionID: session.id) }
            }
        }
    }
    private var modePicker: some View {
        Picker("历史与统计", selection: $mode) { Text("历史").tag("历史"); Text("统计").tag("统计") }
            .pickerStyle(.segmented).accessibilityIdentifier("history.mode")
    }
    private var categoryPicker: some View {
        Picker("记录类型", selection: $category) {
            ForEach(HistoryCategory.allCases) { Text($0.rawValue).tag($0) }
        }.accessibilityIdentifier("history.category")
    }
    private var monthHeader: some View {
        HStack(spacing: 4) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("上个月").accessibilityIdentifier("history.previousMonth")
            Button { choosingDate = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, format: .dateTime.year()).font(.caption).foregroundStyle(.secondary)
                    Text(date, format: .dateTime.month(.defaultDigits)).font(.title2.bold()).foregroundStyle(.primary)
                }
            }.accessibilityLabel("选择月份").accessibilityValue(Text(date, format: .dateTime.year().month())).accessibilityIdentifier("history.month")
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("下个月").accessibilityIdentifier("history.nextMonth")
        }.buttonStyle(.plain)
    }
    private func shift(_ months: Int) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        date = calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
    private func hasRecord(_ value: JournalReviewDay?) -> Bool {
        guard let value else { return false }
        switch category {
        case .training: return !value.sessions.isEmpty
        case .body: return !value.measurements.isEmpty
        case .nutrition: return !value.entries.isEmpty
        }
    }
    private func calendar(_ review: JournalReview) -> some View {
        let byDay = Dictionary(uniqueKeysWithValues: review.days.map { ($0.day, $0) })
        return VStack(spacing: 8) {
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.system(size: typeSize.isAccessibilitySize ? 18 : 13, weight: .semibold)).frame(maxWidth: .infinity).foregroundStyle(.secondary) }
            }.accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7), spacing: 6) {
                ForEach(dates) { value in
                    Button { date = value.date } label: {
                        VStack(spacing: 5) {
                            Text(String(Int(value.day.suffix(2)) ?? 1)).font(.system(size: typeSize.isAccessibilitySize ? 21 : 17))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(value.day == day ? LeanoraTheme.actionInk : value.isInMonth ? Color.primary : Color.secondary)
                                .background(value.day == day ? LeanoraTheme.accent : .clear, in: Circle())
                                .overlay { if value.day == RecordMoment().localDate && value.day != day { Circle().stroke(LeanoraTheme.accent, lineWidth: 1) } }
                            Circle().fill(hasRecord(byDay[value.day]) ? LeanoraTheme.accent : .clear).frame(width: 5, height: 5)
                        }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("\(value.day)，\(hasRecord(byDay[value.day]) ? "有" : "无")\(category.rawValue)记录")
                        .accessibilityAddTraits(value.day == day ? .isSelected : [])
                        .accessibilityIdentifier("history.day.\(value.day)")
                }
            }
        }.padding(.vertical, 12).padding(.horizontal, 4).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func dayDetails(_ value: JournalReviewDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date, format: .dateTime.month().day()).font(.headline)
                Spacer()
                if day != RecordMoment().localDate { Button("回到今天") { date = Date() }.accessibilityIdentifier("history.today") }
            }
            switch category {
            case .training:
                if value.sessions.isEmpty { Text("没有训练记录").foregroundStyle(.secondary).accessibilityIdentifier("history.empty") }
                ForEach(value.sessions) { session in
                    Button { opened = session } label: {
                        HStack {
                            Image(systemName: "dumbbell").foregroundStyle(LeanoraTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(session.status == .completed ? "\(TrainingSummary(sessions: [session]).completedSets) 组 · 已完成" : "已放弃").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.frame(minHeight: 48)
                    }.buttonStyle(.plain).accessibilityIdentifier("history.workout.\(session.id)")
                }
                NavigationLink { TrainingHomeView() } label: { Label("计划与模板", systemImage: "list.clipboard") }.frame(minHeight: 44)
            case .body:
                if value.measurements.isEmpty { Text("没有身体记录").foregroundStyle(.secondary).accessibilityIdentifier("history.empty") }
                ForEach(value.measurements) { item in LabeledContent(item.metric.title, value: bodyValue(item, pounds: preferences.values.weightUnit == .pounds)) }
                NavigationLink { BodyMeasurementView() } label: { Label("记录体重与体脂", systemImage: "plus") }.frame(minHeight: 44)
            case .nutrition:
                if value.entries.isEmpty { Text("没有饮食记录").foregroundStyle(.secondary).accessibilityIdentifier("history.empty") }
                else { NutritionSummaryView(summary: value.nutrition, goal: NutritionCalculator.goal(on: day, goals: journal.goals)) }
                NavigationLink { DietDiaryView(date: date) } label: { Label("饮食日记", systemImage: "fork.knife") }.frame(minHeight: 44).accessibilityIdentifier("history.diary")
                if !value.entries.isEmpty {
                    Button("复制到其他日期", systemImage: "doc.on.doc") { copying = true }.frame(minHeight: 44).accessibilityIdentifier("history.copy")
                }
            }
        }.padding(16).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct HistoryStatisticsView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(TrainingStore.self) private var training
    @Environment(AppPreferences.self) private var preferences
    let date: Date
    let category: HistoryCategory
    @State private var metric = BodyMetric.weightKg
    private var monthDays: [JournalCalendarDay] { JournalMonth.days(containing: date).filter(\.isInMonth) }
    var body: some View {
        let first = monthDays.first?.day ?? RecordMoment(date).localDate
        let last = monthDays.last?.day ?? first
        VStack(alignment: .leading, spacing: 16) {
            switch category {
            case .training:
                let summary = TrainingSummary(sessions: training.sessions, from: first, through: last)
                LabeledContent("完成训练", value: "\(summary.workouts) 次")
                LabeledContent("完成组数", value: "\(summary.completedSets) 组")
                LabeledContent("有效时长", value: "\(Int(summary.activeSeconds / 60)) 分钟")
                let divisor = preferences.values.weightUnit == .pounds ? 0.45359237 : 1
                LabeledContent("正式组容量", value: "\((summary.volumeKg / divisor).formatted(.number.precision(.fractionLength(0...1)))) \(preferences.values.weightUnit.rawValue)·次")
                if summary.workouts > 0 {
                    Chart(monthDays) { item in
                        BarMark(x: .value("日期", item.date, unit: .day), y: .value("容量", TrainingSummary(sessions: training.sessions, from: item.day, through: item.day).volumeKg / divisor)).foregroundStyle(LeanoraTheme.accent)
                    }.frame(height: 170).chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day()) } }
                        .accessibilityLabel("本月正式负重组容量")
                }
            case .body:
                Picker("身体指标", selection: $metric) { ForEach(BodyMetric.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                let values = BodySummary.dailyLatest(journal.measurements, metric: metric).filter { $0.occurred.localDate >= first && $0.occurred.localDate <= last }
                if let latest = values.last {
                    LabeledContent("最近记录", value: bodyValue(latest, pounds: preferences.values.weightUnit == .pounds))
                    let lookup = Dictionary(uniqueKeysWithValues: monthDays.map { ($0.day, $0.date) })
                    Chart(values) { item in
                        LineMark(x: .value("日期", lookup[item.occurred.localDate] ?? date), y: .value(metric.title, item.value / (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1))).foregroundStyle(LeanoraTheme.accent)
                        PointMark(x: .value("日期", lookup[item.occurred.localDate] ?? date), y: .value(metric.title, item.value / (metric == .weightKg && preferences.values.weightUnit == .pounds ? 0.45359237 : 1))).foregroundStyle(LeanoraTheme.accent)
                    }.frame(height: 170).chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { AxisValueLabel(format: .dateTime.month().day()) } }
                } else { Text("本月没有测量记录").foregroundStyle(.secondary) }
            case .nutrition:
                let review = JournalReview(dates: monthDays.map(\.day), sessions: [], entries: journal.entries, measurements: [])
                LabeledContent("记录天数", value: "\(review.dietDays) 天")
                if let average = review.knownEnergyAverage {
                    LabeledContent("已知热量日均", value: "\(average.formatted(.number.precision(.fractionLength(0)))) kcal")
                    let lookup = Dictionary(uniqueKeysWithValues: monthDays.map { ($0.day, $0.date) })
                    Chart(review.days.filter { $0.nutrition.energy.known != nil }) { item in
                        BarMark(x: .value("日期", lookup[item.day] ?? date, unit: .day), y: .value("已知热量", item.nutrition.energy.known ?? 0)).foregroundStyle(LeanoraTheme.accent)
                    }.frame(height: 170).chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day()) } }
                    Text("均值只含有已知热量的记录日").font(.caption).foregroundStyle(.secondary)
                } else { Text("本月没有已知热量记录").foregroundStyle(.secondary) }
            }
            Text("本机记录 · 缺失值不计为零").font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(LeanoraTheme.surface, in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("history.statistics")
    }
}

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
                Text("记录与趋势").font(.title2.bold()).accessibilityIdentifier("screen.trends")
                NavigationLink("日历与周回顾") { JournalReviewView() }.accessibilityIdentifier("trends.review")
                NavigationLink("身体记录与测量") { BodyMeasurementView() }.accessibilityIdentifier("trends.body")
                NavigationLink("训练历史") { WorkoutHistoryView() }
                NavigationLink("健康来源与关联记录") { HealthSyncStatusView() }
                Text("本页统计本机记录。健康来源、重叠训练的主记录与活动统计在来源页查看，运动消耗不重复相加。").font(.caption).foregroundStyle(.secondary)
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
