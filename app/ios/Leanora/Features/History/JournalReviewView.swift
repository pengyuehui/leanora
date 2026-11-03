import SwiftUI

struct JournalReviewView: View {
    @Environment(TrainingStore.self) private var training
    @Environment(JournalStore.self) private var journal
    @Environment(AppPreferences.self) private var preferences
    @State private var date = Date()
    @State private var opened: WorkoutSession?
    @State private var copying = false
    private var day: String { RecordMoment(date).localDate }
    private var review: JournalReview {
        JournalReview(dates: JournalReview.week(containing: date), sessions: training.sessions, entries: journal.entries, measurements: journal.measurements)
    }

    var body: some View {
        let week = review
        List {
            Section {
                Text("每一天，都有迹可循").font(.title2.bold()).accessibilityIdentifier("review.title")
                RecordDatePicker(title: "查看日期", selection: $date, components: .date).accessibilityIdentifier("review.date")
                HStack {
                    Button { shift(-7) } label: { Label("前一周", systemImage: "chevron.left") }.accessibilityIdentifier("review.previous")
                    Spacer()
                    Button("今天") { date = Date() }.accessibilityIdentifier("review.today")
                    Spacer()
                    Button { shift(7) } label: { Label("后一周", systemImage: "chevron.right") }.accessibilityIdentifier("review.next")
                }.frame(minHeight: 44).buttonStyle(.borderless)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(week.days.enumerated()), id: \.element.id) { index, value in
                                Button { select(value.day) } label: {
                                    VStack(spacing: 6) {
                                        Text(["一", "二", "三", "四", "五", "六", "日"][index]).font(.caption)
                                        Text(String(value.day.suffix(2))).font(.headline.monospacedDigit())
                                        HStack(spacing: 3) {
                                            if value.training.workouts > 0 { Image(systemName: "dumbbell.fill") }
                                            if !value.entries.isEmpty { Image(systemName: "fork.knife") }
                                            if !value.measurements.isEmpty { Image(systemName: "scalemass") }
                                            if !value.hasRecords { Text("—") }
                                        }.font(.caption2).frame(minHeight: 16)
                                    }.frame(minWidth: 48, minHeight: 82).padding(.horizontal, 4)
                                        .foregroundStyle(value.day == day ? LeanoraTheme.actionInk : .primary)
                                        .background(value.day == day ? LeanoraTheme.accent : LeanoraTheme.canvas, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).id(value.day)
                                    .accessibilityLabel("\(value.day)，\(value.training.workouts) 次完成训练，\(value.entries.count) 项饮食，\(value.measurements.count) 类身体记录")
                                    .accessibilityAddTraits(value.day == day ? .isSelected : [])
                                    .accessibilityIdentifier("review.day.\(value.day)")
                            }
                        }.padding(.vertical, 4)
                    }.scrollIndicators(.hidden)
                        .onAppear { proxy.scrollTo(day, anchor: .center) }
                        .onChange(of: day) { proxy.scrollTo(day, anchor: .center) }
                }
            }
            Section("这一周 · \(week.days.first?.day ?? "") 至 \(week.days.last?.day ?? "")") {
                LabeledContent("训练天数 / 次数", value: "\(week.trainingDays) 天 / \(week.workouts) 次").accessibilityIdentifier("review.trainingCount")
                LabeledContent("已完成组数（含各组类型）", value: "\(week.completedSets) 组")
                LabeledContent("有饮食记录", value: "\(week.dietDays) / 7 天")
                LabeledContent("所记营养字段均有值", value: "\(week.completeNutrientDays) 天")
                if let average = week.knownEnergyAverage { LabeledContent("有热量记录日的已知均值", value: "\(average.formatted(.number.precision(.fractionLength(0...1)))) kcal") }
                Text("只统计本机记录。有记录不等于全天完整；均值排除无已知热量日期，未知营养不当作零。训练按开始时当地日期计入；健康外部来源另页查看。").font(.caption).foregroundStyle(.secondary)
            }
            if let selected = week.days.first(where: { $0.day == day }) {
                Section("\(day) · 训练") {
                    if selected.sessions.isEmpty { Text("这一天没有已结束训练").foregroundStyle(.secondary) }
                    ForEach(selected.sessions) { session in
                        Button { opened = session } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.name).font(.headline)
                                Text(session.status == .completed ? "已完成 · \(TrainingSummary(sessions: [session]).completedSets) 组" : "已放弃 · 不计入完成次数").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }.accessibilityIdentifier("review.workout.\(session.id)")
                    }
                    NavigationLink("查看全部训练历史") { WorkoutHistoryView() }
                }
                Section("\(day) · 饮食") {
                    NutritionSummaryView(summary: selected.nutrition, goal: NutritionCalculator.goal(on: day, goals: journal.goals))
                    ForEach(Meal.allCases) { meal in
                        let summary = NutritionSummary(entries: selected.entries, meal: meal)
                        LabeledContent(meal.title, value: summary.count == 0 ? "还没有记录" : "\(summary.count) 项 · \(summary.energy.text) kcal")
                    }
                    NavigationLink("打开这一天的饮食日记") { DietDiaryView(date: date) }.accessibilityIdentifier("review.diary")
                    Button("把这一天复制到其他日期", systemImage: "doc.on.doc") { copying = true }.disabled(selected.entries.isEmpty).accessibilityIdentifier("review.copy")
                }
                Section("\(day) · 身体") {
                    if selected.measurements.isEmpty { Text("这一天没有身体测量").foregroundStyle(.secondary) }
                    ForEach(selected.measurements) { value in LabeledContent(value.metric.title, value: bodyValue(value, pounds: preferences.values.weightUnit == .pounds)) }
                    Text("同一测量类型取当日最后一次。本页不会因没有记录推断身体变化。").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("身体记录与测量") { BodyMeasurementView() }
                }
            }
            Section("复盘方法") {
                NavigationLink("训练复盘与记录指南") { TrainingGuidesView() }
                NavigationLink("饮食回顾与记录指南") { NutritionGuidesView() }
            }
            TrainingErrorNotice(); JournalErrorNotice()
        }
        .navigationTitle("日历与周回顾").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task { await training.refresh(); await journal.refresh() }
        .refreshable { await training.refresh(); await journal.refresh() }
        .sheet(isPresented: $copying) { NavigationStack { DietDayCopyView(destination: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date, source: date) } }
        .sheet(item: $opened, onDismiss: { Task { await training.refresh() } }) { session in NavigationStack {
            if session.status == .abandoned {
                List { Text(session.name); Text("该训练已放弃，不计入训练次数、容量或 PR。") }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { opened = nil } } }
            } else { ActiveWorkoutView(sessionID: session.id) }
        } }
    }
    private func shift(_ days: Int) { date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date }
    private func select(_ day: String) {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        if let value = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) { date = value }
    }
}
