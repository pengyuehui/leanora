import SwiftUI
import UserNotifications

struct LocalResetView: View {
    @Environment(DataStoreController.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool
    var body: some View {
        Form {
            Section {
                Text("训练、模板、饮食、身体数据、目标和本机恢复副本将被清除。导出到文件 App 的备份需你自行管理。")
                Text("Apple Health 的数据会保留；自动同步停止，恢复备份后也不会自动批量写入。")
                TextField("输入「清除」确认", text: $confirmation).focused($focused).submitLabel(.done).onSubmit { focused = false }.accessibilityIdentifier("data.resetText")
                Text("输入后，点右上角「清除」执行。").font(.footnote).foregroundStyle(.secondary)
            } header: { Text("请先导出需要保留的备份") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("清除本机资料").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button("清除", role: .destructive) { focused = false; Task { await reset() } }.disabled(confirmation != "清除" || busy).accessibilityIdentifier("data.confirmReset") }
            }
            .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("data.keyboardDone") }.padding(.horizontal).background(.bar) } }
    }
    private func reset() async {
        guard let repository = store.repository else { return }
        busy = true; defer { busy = false }
        if let sync = store.healthSync, !(await sync.stop()) { error = "同步设置尚未保存，请先重试停止同步。"; return }
        do {
            try await repository.resetLocalData()
            try await store.removeLocalRecoveries()
            preferences.trainingRemindersEnabled = false
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            try await store.restorePreferences(from: repository, into: preferences)
            await store.training?.refresh(); await store.journal?.refresh(); await store.healthSync?.refresh()
            dismiss()
        } catch { self.error = "清除未全部完成，请解锁设备后重试。" }
    }
}
