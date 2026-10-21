import SwiftUI

struct HealthConnectionView: View {
    @Environment(HealthAuthorizationService.self) private var health
    @Environment(AppPreferences.self) private var preferences
    @Environment(DataStoreController.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = HealthAccessSelection()

    var body: some View {
        Form {
            Section {
                Label("你的健康数据，由你决定。", systemImage: "heart")
                    .font(.headline).padding(.vertical, 6)
                Text("选择访问范围后，再在系统页面确认。你可以随时在「健康」App 中调整权限。")
                    .foregroundStyle(.secondary)
                Text("首次读取最近 90 天。新记录按你选择的方向同步；历史记录需单独确认导出。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let sync = store.healthSync {
                Section {
                    Toggle("自动同步", isOn: Binding(get: { sync.configuration.enabled }, set: { enabled in
                        Task { var config = sync.configuration; config.enabled = enabled; await sync.configure(config); if enabled { await sync.sync() } }
                    })).accessibilityIdentifier("health.auto")
                    NavigationLink("同步状态与健康摘要") { HealthSyncStatusView() }.accessibilityIdentifier("health.status")
                } footer: { Text("停止自动同步会取消尚未开始的自动任务，保留历史副本。单独请求的副本删除仍可执行；已开始的写入可能完成。") }
            }
            if health.isAvailable {
                ForEach(HealthCategory.allCases) { category in
                    Section {
                        Toggle("读取", isOn: binding(category, writing: false))
                            .accessibilityLabel("读取\(category.title)")
                            .accessibilityIdentifier("health.read.\(category.rawValue)")
                        if category != .activity {
                            Toggle("写入", isOn: binding(category, writing: true))
                                .accessibilityLabel("写入\(category.title)")
                                .accessibilityIdentifier("health.write.\(category.rawValue)")
                        }
                    } header: { Text(category.title) } footer: { Text(category.detail) }
                    .disabled(health.isRequesting)
                }
                Section {
                    Button {
                        Task {
                            if await health.request(selection) {
                                preferences.markHealthRequestProcessed()
                                if let sync = store.healthSync {
                                    var config = sync.configuration
                                    config.enabled = true; config.generation = UUID(); config.queryStart = Date().addingTimeInterval(-90 * 86_400)
                                    config.reading = Set(selection.reading.flatMap(\.components)); config.writing = Set(selection.writing.flatMap(\.components))
                                    config.readActivity = selection.reading.contains(.activity)
                                    await sync.configure(config); await sync.sync()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(health.isRequesting ? "正在等待系统回应…" : "在系统中设置访问")
                            Spacer()
                            if health.isRequesting { ProgressView() }
                        }
                    }.disabled(selection.isEmpty || health.isRequesting)
                        .accessibilityIdentifier("health.request")
                    if selection.isEmpty { Text("请先选择至少一种访问范围。").font(.footnote).foregroundStyle(.secondary) }
                    status
                }
            } else {
                Section {
                    Label("此设备无法使用 Apple Health", systemImage: "heart.slash")
                        .accessibilityIdentifier("health.unavailable")
                    Text("你仍可使用 App，也可以稍后在支持的 iPhone 上设置健康访问。")
                        .foregroundStyle(.secondary)
                }
            }
            Section("关于读取权限") {
                Text("系统不会告知 App 是否获得了某项读取权限。没有读到数据，也可能是暂时没有可访问的记录。")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.frame(minHeight: 44)
            }
        }
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { health.refreshWriteAccess() }
        .task {
            if let sync = store.healthSync {
                await sync.refresh()
                if sync.configuration.enabled {
                    selection.reading = Set(HealthCategory.allCases.filter { !$0.components.isDisjoint(with: sync.configuration.reading) || ($0 == .activity && sync.configuration.readActivity) })
                    selection.writing = Set(HealthCategory.allCases.filter { !$0.components.isDisjoint(with: sync.configuration.writing) })
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { health.refreshWriteAccess() }
        }
    }

    @ViewBuilder private var status: some View {
        switch health.state {
        case .idle:
            if preferences.lastHealthRequest != nil {
                Text("曾完成系统访问设置。你可以重新检查访问范围。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .requesting: EmptyView()
        case let .processed(writable, requested):
            VStack(alignment: .leading, spacing: 8) {
                Label("已完成系统访问设置", systemImage: "checkmark.circle")
                Text("读取范围以系统允许为准。这不表示所有数据类型都已授权，也不表示记录已同步。")
                    .font(.footnote).foregroundStyle(.secondary)
                if requested > 0 { Text("上次请求范围内可写：\(writable) / \(requested) 种数据类型").font(.footnote) }
            }.accessibilityIdentifier("health.processed")
        case .failed:
            Text("未能完成系统请求。你可以重试，或稍后在健康访问中设置。")
                .foregroundStyle(.red).accessibilityIdentifier("health.failed")
        }
    }

    private func binding(_ category: HealthCategory, writing: Bool) -> Binding<Bool> {
        Binding {
            writing ? selection.writing.contains(category) : selection.reading.contains(category)
        } set: { enabled in
            if writing {
                if enabled { selection.writing.insert(category) } else { selection.writing.remove(category) }
            } else {
                if enabled { selection.reading.insert(category) } else { selection.reading.remove(category) }
            }
        }
    }
}
