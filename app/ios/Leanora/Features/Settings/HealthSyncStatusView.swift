import SwiftUI

struct HealthSyncStatusView: View {
    @Environment(DataStoreController.self) private var store
    @State private var exportConfirmation = false
    var body: some View {
        Form {
            if let sync = store.healthSync {
                Section("同步状态") {
                    LabeledContent("自动同步", value: sync.configuration.enabled ? "开启" : "停止")
                    LabeledContent("待处理组件", value: "\(sync.jobs.count)").accessibilityIdentifier("health.pending")
                    LabeledContent("需重试组件", value: "\(sync.jobs.filter { $0.errorCategory != nil }.count)")
                    LabeledContent("已关联本机组件", value: "\(sync.metadata.filter { if case .currentLink(let link) = $0 { return link.state == .written }; return false }.count)").accessibilityIdentifier("health.linked")
                    let held = sync.metadata.filter { if case .hold = $0 { return true }; return false }.count
                    if held > 0 { Text("\(held) 条恢复记录等待确认历史导出；编辑这些记录不会自动覆盖健康副本。").font(.footnote).foregroundStyle(.secondary) }
                    let removed = sync.metadata.filter { if case .componentSuppression = $0 { return true }; return false }.count
                    if removed > 0 { Text("\(removed) 个组件已请求移除，自动补写已暂停；重新导出需单独确认。").font(.footnote).foregroundStyle(.secondary) }
                    if let date = sync.check?.succeededAt { LabeledContent("最近成功检查") { Text(date, format: .dateTime.month().day().hour().minute()) } }
                    Text("读取：按系统允许的可读范围").font(.footnote).foregroundStyle(.secondary)
                    if sync.cachedCount == 0 && !sync.metadata.contains(where: { if case .currentLink(let link) = $0 { return link.state == .written }; return false }) {
                        Text("暂未读到数据，可检查健康访问或手动记录。").font(.footnote).foregroundStyle(.secondary)
                    } else { Text("本机副本按关联识别，不重复显示在健康来源摘要中。").font(.footnote).foregroundStyle(.secondary) }
                    if let message = sync.error ?? sync.check?.message { Label(message, systemImage: "exclamationmark.triangle") }
                    Button(sync.busy ? "正在检查…" : "检查并重试") { Task { await sync.sync() } }
                        .disabled(sync.busy || (!sync.configuration.enabled && !sync.jobs.contains { $0.userInitiated == true })).accessibilityIdentifier("health.retry")
                }
                Section("读入与写入范围") {
                    ForEach(HealthComponent.allCases, id: \.self) { component in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(component.title)
                            Text("\(sync.configuration.reading.contains(component) ? "读入" : "不读取") · \(sync.configuration.writing.contains(component) ? "写入本 App 新记录" : "不写入")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("首次范围：\(sync.configuration.queryStart.formatted(date: .abbreviated, time: .omitted)) 起。后台检查由系统安排。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if sync.needsReconciliation {
                    Section("恢复后核对") {
                        Text("备份不包含健康映射。先核对已有样本，再决定是否导出历史；核对不会覆盖健康中的更新版本。")
                        Button("核对已有健康样本") { Task { await sync.reconcile() } }.disabled(sync.busy).accessibilityIdentifier("health.reconcile")
                    }
                }
                Section {
                    Button("重新导出本机历史记录") { exportConfirmation = true }
                        .disabled(sync.busy || sync.needsReconciliation || !sync.configuration.enabled).accessibilityIdentifier("health.exportHistory")
                    Text("只有这项明确操作才会解除恢复或手动移除的导出限制。营养每个组件独立处理。")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(sync.jobs.filter { $0.errorCategory != nil }, id: \.key) { job in
                        Text("\(job.component.title)：\(job.errorCategory ?? "") · 已尝试 \(job.attempts) 次").font(.footnote)
                    }
                }
                if let activity = sync.activity, sync.configuration.readActivity {
                    Section("今日活动 · Apple Health 统计") {
                        LabeledContent("步数", value: activity.steps.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "暂无可读数据")
                        LabeledContent("活动能量", value: activity.activeEnergyKcal.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "暂无可读数据")
                        Text("\(activity.timeZoneID) · 不与训练消耗相加，来源合并由 HealthKit 统计处理。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("健康来源摘要 · \(sync.cachedCount) 条") {
                    Text("外部记录只读，与本机餐次明细分开。若训练时段重叠，请保留一个主记录看时长；此处不合计到本机训练统计。")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(sync.cache, id: \.key) { record in HealthExternalRow(record: record) }
                    if sync.cache.count < sync.cachedCount { Button("加载更多") { Task { await sync.loadMore() } } }
                }
            }
        }
        .navigationTitle("健康同步").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task { await store.healthSync?.refresh() }
        .confirmationDialog("重新导出历史记录？", isPresented: $exportConfirmation, titleVisibility: .visible) {
            Button("确认重新导出") { Task { await store.healthSync?.exportHistory() } }
        } message: { Text("将按本机内容更新允许写入的组件，包括恢复的数据及曾在健康中手动删除的副本。请确认本机内容是你要保留的版本。") }
    }
}

private struct HealthExternalRow: View {
    let record: HealthRuntimeRecord
    @Environment(DataStoreController.self) private var store
    @State private var linking = false
    private func unit(_ component: HealthComponent) -> String {
        switch component { case .weight: "kg"; case .bodyFat: "%"; case .energy: "kcal"; case .workout: ""; default: "g" }
    }
    private var value: HealthSampleValue? {
        switch record {
        case .workout(let v): HealthSampleValue(id: v.sampleUUID, source: v.sourceBundleID, component: .workout, start: v.started, end: v.endedAt, value: nil, activity: v.activityType)
        case .nutrition(let v): HealthSampleValue(id: v.sampleUUID, source: v.sourceBundleID, component: v.component, start: v.occurred, end: v.occurred.instant, value: v.value)
        case .body(let v): HealthSampleValue(id: v.sampleUUID, source: v.sourceBundleID, component: v.metric == .weightKg ? .weight : .bodyFat, start: v.occurred, end: v.occurred.instant, value: v.value)
        default: nil
        }
    }
    var body: some View {
        if let value {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(value.component.title).font(.headline); Spacer(); if let number = value.value { Text("\(number.formatted(.number.precision(.fractionLength(0...2)))) \(unit(value.component))").monospacedDigit() } }
                Text("\(value.start.localDate) · \(value.source)").font(.caption).foregroundStyle(.secondary)
                if case .workout(let external) = record {
                    Text("\(Int((external.durationSeconds ?? value.end.timeIntervalSince(value.start.instant)) / 60)) 分钟 · \(value.activity)").font(.caption)
                    let local = (store.training?.sessions ?? []).filter { HealthAggregation.overlaps($0, external) }
                    if !local.isEmpty {
                        Label("时段重叠，可能重复", systemImage: "rectangle.on.rectangle").font(.caption).foregroundStyle(.secondary)
                        Button("选择主记录并关联") { linking = true }.font(.caption).frame(minHeight: 44)
                    }
                    if let association = store.healthSync?.metadata.compactMap({ if case .association(let v) = $0, v.sampleUUID == external.sampleUUID { return v }; return nil }).first,
                       let session = local.first(where: { $0.id == association.businessID }) {
                        Text("已关联《\(session.name)》· 主记录：\(association.primary == .local ? "本机" : "健康") · \(Int(HealthAggregation.primaryDuration(local: session, external: external, choice: association.primary) / 60)) 分钟（计一次）").font(.caption)
                    }
                }
                Button("在本 App 隐藏", role: .destructive) {
                    Task { await store.healthSync?.hide(value) }
                }.font(.caption).frame(minHeight: 44)
            }
            .sheet(isPresented: $linking) { if case .workout(let external) = record { NavigationStack { HealthWorkoutAssociationView(workout: external) } } }
        }
    }
}
