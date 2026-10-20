import SwiftUI

struct StoreUnavailableView: View {
    let message: String
    @Environment(DataStoreController.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var showingRecovery = false
    @State private var selection: URL?

    var body: some View {
        ContentUnavailableView {
            Label("资料库暂不可用", systemImage: "externaldrive.badge.exclamationmark")
        } description: { Text(message).accessibilityIdentifier("store.error") } actions: {
            Button("重试") { Task { await store.start(preferences: preferences) } }.accessibilityIdentifier("store.retry")
            if !store.recoveries.isEmpty { Button("查看升级恢复副本") { showingRecovery = true } }
        }
        .disabled(store.isStarting)
        .sheet(isPresented: $showingRecovery) {
            NavigationStack {
                List {
                    Section {
                        Text("恢复到所选时间点。当前文件会另外保留，不删除 Apple Health 中的样本。请优先重试打开；只有升级无法继续时才使用旧副本。")
                    }
                    ForEach(store.recoveries, id: \.self) { url in
                        Button {
                            selection = url
                        } label: {
                            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                            Text(date, format: .dateTime.year().month().day().hour().minute().second())
                        }
                    }
                }
                .navigationTitle("升级恢复副本")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { showingRecovery = false } } }
                .confirmationDialog("恢复此时间点的资料？", isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }), titleVisibility: .visible) {
                    Button("恢复所选副本", role: .destructive) {
                        guard let selection else { return }
                        showingRecovery = false
                        Task { await store.restore(selection, preferences: preferences) }
                    }
                } message: { Text("当前文件会另存保留。所选副本之后的记录可能需要从 JSON 备份重新导入。") }
            }
        }
    }
}
