import SwiftUI

struct HealthConnectionView: View {
    @Environment(HealthAuthorizationService.self) private var health
    @Environment(AppPreferences.self) private var preferences
    @Environment(DataStoreController.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = HealthAccessSelection()
    @State private var connecting = false

    var body: some View {
        Form {
            Section {
                if health.isAvailable {
                    Button { Task { await connect() } } label: {
                        HStack {
                            Label(connecting ? "正在连接…" : preferences.lastHealthRequest == nil ? "连接 Apple Health" : "检查访问与同步", systemImage: "heart.fill")
                            Spacer()
                            if connecting { ProgressView() }
                        }.frame(minHeight: 44)
                    }.disabled(selection.isEmpty || connecting).accessibilityIdentifier("health.request")
                    status
                    if let error = store.healthSync?.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            if let sync = store.healthSync {
                Section {
                    Toggle("自动同步", isOn: Binding(get: { sync.configuration.enabled }, set: { enabled in
                        Task { if enabled { await connect() } else { _ = await sync.stop() } }
                    })).disabled(connecting || !health.isAvailable).accessibilityIdentifier("health.auto")
                    NavigationLink("同步状态与健康摘要") { HealthSyncStatusView() }.accessibilityIdentifier("health.status")
                    if sync.busy { ProgressView("正在同步…") }
                }
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
                    } header: { Text("\(category.title) · \(category.detail)") }
                    .disabled(connecting)
                }
                Section {
                    if selection.isEmpty { Text("请先选择至少一种访问范围。").font(.footnote).foregroundStyle(.secondary) }
                    Text("历史记录需在同步状态页单独确认导出。").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Label("此设备无法使用 Apple Health", systemImage: "heart.slash")
                        .accessibilityIdentifier("health.unavailable")
                    Text("你仍可使用 App，也可以稍后在支持的 iPhone 上设置健康访问。")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                DisclosureGroup("权限与同步帮助") {
                    Text("读取和写入分别授权。写入开关只对新记录生效，历史数据不会自动补写。")
                    Text("已设置过的权限不会重复弹窗。请在「健康」App 的个人资料中打开「App」，选择 Leanora Fitness 调整。")
                    Text("系统不提供读取授权状态；没有数据可能是未允许、没有记录或超出允许的历史范围。默认查询最近 90 天，实际以系统允许为准。")
                    Text("暂停同步保留已有副本；已开始的写入可能完成。")
                }.font(.footnote)
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
                if sync.configuration.enabled || preferences.lastHealthRequest != nil || !sync.configuration.writing.isEmpty {
                    selection = HealthAccessSelection(configuration: sync.configuration)
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
                Text(store.healthSync?.configuration.enabled == true ? "自动同步已开启" : "同步已暂停")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .requesting: EmptyView()
        case let .processed(writable, requested):
            VStack(alignment: .leading, spacing: 8) {
                Label("已完成系统访问设置", systemImage: "checkmark.circle")
                if requested > 0 { Text("允许写入 \(writable)/\(requested) 类。读取以系统允许为准。").font(.footnote) }
                Text("已设置过的权限不会重复弹窗；请到「健康」App 的个人资料 → App → Leanora Fitness 调整。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.accessibilityIdentifier("health.processed")
        case .failed:
            Text(health.failureMessage ?? "系统授权未完成，请重试。")
                .foregroundStyle(.red).accessibilityIdentifier("health.failed")
            if let code = health.failureCode { Text(code).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).accessibilityIdentifier("health.failureCode") }
        }
    }

    private func connect() async {
        guard !connecting, !selection.isEmpty, let sync = store.healthSync else { return }
        connecting = true; defer { connecting = false }
        let requested = selection
        if await sync.connect(requested, authorization: health) { preferences.markHealthRequestProcessed() }
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
