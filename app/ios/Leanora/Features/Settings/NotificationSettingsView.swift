import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(NotificationPermissionService.self) private var notifications
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var pendingCount: Int?

    var body: some View {
        Form {
            @Bindable var preferences = preferences
            Section {
                Label("在需要时，轻轻提醒。", systemImage: "bell")
                    .font(.headline).padding(.vertical, 6)
                Text("通知用于训练与休息提醒。即使不允许通知，也能继续使用 App。")
                    .foregroundStyle(.secondary)
            }
            Section("系统通知权限") {
                Group {
                    switch notifications.access {
                    case .unknown: Text("正在检查…")
                    case .notDetermined: Text("尚未设置")
                    case .allowed: Label("已允许通知", systemImage: "checkmark.circle")
                    case .denied:
                        Text("通知未开启").accessibilityIdentifier("notifications.denied")
                        Text("你仍可继续使用全部页面。需要提醒时，可在系统设置中允许通知。")
                            .font(.footnote).foregroundStyle(.secondary)
                    case .failed:
                        Text("未能完成通知请求，请稍后重试。")
                            .accessibilityIdentifier("notifications.failed")
                    }
                }
                if notifications.access == .denied || notifications.access == .allowed {
                    Button("打开系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    Button("允许通知") { Task { await notifications.request() } }
                        .disabled(notifications.isRequesting)
                        .accessibilityIdentifier("notifications.request")
                }
            }
            Section("训练安排提醒") {
                Toggle("提醒当天训练", isOn: $preferences.trainingRemindersEnabled).accessibilityIdentifier("notifications.trainingEnabled")
                if preferences.trainingRemindersEnabled {
                    Stepper("提醒时间：\(String(format: "%02d", preferences.trainingReminderHour)) 时", value: $preferences.trainingReminderHour, in: 0...23)
                    Stepper("\(String(format: "%02d", preferences.trainingReminderMinute)) 分", value: $preferences.trainingReminderMinute, in: 0...59)
                }
                Text("根据周计划和单次改期安排未来 14 天的提醒，打开 App 时更新。系统通知需已允许；休息与计时目标提醒随正在进行的训练自动安排。").font(.caption).foregroundStyle(.secondary)
                if let pendingCount { Text("待送达提醒：\(pendingCount)").accessibilityIdentifier("notifications.pending") }
                Button("刷新提醒状态") { Task { await refresh() } }.accessibilityIdentifier("notifications.refresh")
            }
        }
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .navigationTitle("通知访问").navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }
    private func refresh() async {
        await notifications.refresh()
        pendingCount = await UNUserNotificationCenter.current().pendingNotificationRequests().filter { $0.identifier.hasPrefix("leanora.") }.count
    }
}
