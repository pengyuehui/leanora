import SwiftUI

struct SettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    LeanoraMark(size: 52)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Leanora")
                            .font(.headline).accessibilityIdentifier("screen.settings")
                        Text("训练与饮食记录 · 0.2").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 10)
            }.listRowBackground(LeanoraTheme.surface)
            if let notice = preferences.storageNotice {
                Section { Text(notice).foregroundStyle(.secondary) }
            }
            Section("按照你的习惯") {
                NavigationLink { PreferencesEditorView() } label: {
                    settingsRow("单位与目标", symbol: "slider.horizontal.3", detail: preferences.values.weightUnit.rawValue)
                }.accessibilityIdentifier("settings.preferences")
                NavigationLink { NotificationSettingsView() } label: {
                    settingsRow("通知访问", symbol: "bell")
                }.accessibilityIdentifier("settings.notifications")
            }
            Section("数据由你掌握") {
                NavigationLink { HealthConnectionView() } label: {
                    settingsRow("Apple Health", symbol: "heart")
                }.accessibilityIdentifier("settings.health")
                NavigationLink { DataManagementView() } label: {
                    settingsRow("数据管理", symbol: "externaldrive")
                }.accessibilityIdentifier("settings.data")
                NavigationLink { PrivacyView() } label: {
                    settingsRow("隐私与数据", symbol: "hand.raised")
                }.accessibilityIdentifier("settings.privacy")
            }
            Section {
                Text("本机保存 · 可导出 · Apple Health 按需同步")
                    .font(.footnote).foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .navigationTitle("我的")
    }

    private func settingsRow(_ title: String, symbol: String, detail: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(LeanoraTheme.accent).frame(width: 24)
            Text(title)
            Spacer()
            if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(minHeight: 38)
    }
}
