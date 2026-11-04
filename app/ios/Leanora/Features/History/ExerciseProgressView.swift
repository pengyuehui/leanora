import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let exerciseID: UUID
    let name: String
    let measurement: ExerciseMeasurement
    @Environment(TrainingStore.self) private var training
    @Environment(AppPreferences.self) private var preferences
    @State private var opened: WorkoutSession?
    private var rows: [ExerciseProgressEntry] { ExerciseProgress.history(exerciseID: exerciseID, measurement: measurement, sessions: training.sessions) }
    private var divisor: Double { preferences.values.weightUnit == .pounds ? 0.45359237 : 1 }
    private var unit: String { preferences.values.weightUnit.rawValue }

    var body: some View {
        List {
            Section {
                Text(name).font(.title2.bold())
                Text("只比较已完成训练中的已完成正式组。同次重复动作合并；热身、递减、力竭组和未完成组不计入本页。").font(.footnote).foregroundStyle(.secondary)
            }
            TrainingErrorNotice()
            if let latest = rows.first {
                Section("最近一次 · \(latest.session.started.localDate)") {
                    metrics(latest)
                    Text("\(latest.sets.count) 个正式组").accessibilityIdentifier("progress.latestSets")
                }
                if rows.count > 1 {
                    let prior = rows[1]
                    Section("与上一次比较 · \(prior.session.started.localDate)") {
                        switch measurement {
                        case .externalLoad:
                            delta("正式组容量变化", (latest.volumeKg! - prior.volumeKg!) / divisor, "\(unit)·次")
                            if let a = latest.bestLoadKg, let b = prior.bestLoadKg { delta("最高实际负重变化", (a - b) / divisor, unit) }
                        case .bodyweight, .assistedLoad: delta("正式组总次数变化", Double(latest.repetitions - prior.repetitions), "次")
                        case .duration: delta("实际时长变化", latest.duration - prior.duration, "秒")
                        case .cardio:
                            delta("实际时长变化", latest.duration - prior.duration, "秒")
                            if let a = latest.distance, let b = prior.distance, latest.missingDistance == 0, prior.missingDistance == 0 {
                                delta("实际距离变化", a - b, "m")
                            } else { Text("距离记录不完整，暂不比较差值").font(.caption).foregroundStyle(.secondary) }
                        }
                        Text("差值描述记录变化，不自动判断训练效果；动作幅度、器械和组数也会影响比较。").font(.caption).foregroundStyle(.secondary)
                    }.accessibilityIdentifier("progress.comparison")
                } else { Section { Text("再完成一次同类型动作后，可查看两次记录的差异。").foregroundStyle(.secondary) } }
                if measurement == .externalLoad, rows.count > 1 {
                    Section("最近 20 次正式组容量") {
                        Chart(Array(rows.prefix(20).reversed().enumerated()), id: \.element.id) { index, row in
                            BarMark(x: .value("训练顺序", index), y: .value("容量", (row.volumeKg ?? 0) / divisor))
                                .foregroundStyle(LeanoraTheme.accent)
                                .accessibilityLabel("\(row.session.started.localDate)，\(row.session.name)")
                                .accessibilityValue("正式组容量 \(((row.volumeKg ?? 0) / divisor).formatted()) \(unit)·次")
                        }.chartXAxis(.hidden).frame(height: 140).accessibilityLabel("按先后排列的最近正式组容量，单位 \(unit)·次。下方逐次记录提供日期和数值。")
                    }
                }
            } else {
                Section { ContentUnavailableView("还没有可比较记录", systemImage: "chart.xyaxis.line", description: Text("完成这个记录类型的正式组后，逐次表现会出现在这里。")) }
            }
            ForEach(Array(rows.prefix(100))) { row in
                Section("\(row.session.started.localDate) · \(row.session.name)") {
                    metrics(row)
                    ForEach(Array(row.sets.enumerated()), id: \.element.id) { index, set in
                        Text("\(index + 1). \(actual(set))").monospacedDigit().font(.subheadline)
                    }
                    ForEach(row.exercises.filter { !$0.notes.isEmpty }, id: \.id) { Text($0.notes).font(.footnote).foregroundStyle(.secondary) }
                    Button("查看来源训练", systemImage: "arrow.up.forward.square") { opened = row.session }.accessibilityIdentifier("progress.source.\(row.id)")
                }
            }
            Section {
                Text("最多显示最近 100 次来源训练。历史编辑、删除后重新计算；不估算 1RM，辅助负重不记为正向负重纪录。").font(.caption).foregroundStyle(.secondary)
                NavigationLink("训练复盘指南") { TrainingGuidesView() }.accessibilityIdentifier("progress.guides")
            }
        }
        .navigationTitle("动作历史与进步").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task { await training.refresh() }
        .sheet(item: $opened, onDismiss: { Task { await training.refresh() } }) { session in NavigationStack { ActiveWorkoutView(sessionID: session.id) } }
    }

    @ViewBuilder private func metrics(_ row: ExerciseProgressEntry) -> some View {
        switch measurement {
        case .externalLoad:
            LabeledContent("正式组容量", value: "\(((row.volumeKg ?? 0) / divisor).formatted()) \(unit)·次")
            if let best = row.bestLoadKg { LabeledContent("最高实际负重", value: "\((best / divisor).formatted()) \(unit)") }
        case .bodyweight: LabeledContent("自重正式组次数", value: "\(row.repetitions) 次")
        case .assistedLoad: LabeledContent("辅助正式组次数", value: "\(row.repetitions) 次")
        case .duration: LabeledContent("实际时长", value: "\(row.duration.formatted()) 秒")
        case .cardio:
            LabeledContent("实际时长", value: "\(row.duration.formatted()) 秒")
            LabeledContent("已记录距离", value: row.distance.map { "\($0.formatted()) m\(row.missingDistance > 0 ? "（部分）" : "")" } ?? "未记录")
                .accessibilityElement(children: .combine).accessibilityIdentifier("progress.distance")
            if row.missingDistance > 0 { Text("\(row.missingDistance) 个正式组未记录距离").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func delta(_ title: String, _ value: Double, _ suffix: String) -> some View {
        LabeledContent(title, value: "\(value > 0 ? "+" : "")\(value.formatted(.number.precision(.fractionLength(0...1)))) \(suffix)")
    }
    private func actual(_ set: WorkoutSet) -> String {
        switch measurement {
        case .externalLoad, .assistedLoad: "\(set.loadKg.map { ($0 / divisor).formatted() } ?? "—") \(unit) × \(set.repetitions ?? 0) 次\(measurement == .assistedLoad ? "（辅助）" : "")"
        case .bodyweight: "\(set.repetitions ?? 0) 次"
        case .duration: "\(set.durationSeconds?.formatted() ?? "—") 秒"
        case .cardio: "\(set.durationSeconds?.formatted() ?? "—") 秒 · \(set.distanceMeters?.formatted() ?? "—") m"
        }
    }
}
