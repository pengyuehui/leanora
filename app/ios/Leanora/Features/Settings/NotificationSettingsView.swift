import SwiftUI

struct NotificationSettingsView: View {
    @Environment(NotificationPermissionService.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
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
        }
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .navigationTitle("通知访问").navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notifications.refresh() } }
        }
    }
}
