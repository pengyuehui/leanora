import SwiftUI

enum AppTab: String, Hashable {
    case history, exercises, nutrition, settings
}

struct MainTabView: View {
    @State private var selected: AppTab = .history
    var body: some View {
        TabView(selection: $selected) {
            Tab("历史", systemImage: "clock.fill", value: .history) {
                NavigationStack { HistoryHomeView(selected: $selected) }
            }
            Tab("动作", systemImage: "figure.strengthtraining.traditional", value: .exercises) {
                NavigationStack { ExerciseLibraryView() }
            }
            Tab("饮食", systemImage: "fork.knife", value: .nutrition) {
                NavigationStack { DietDiaryView() }
            }
            Tab("我的", systemImage: "person.crop.circle", value: .settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.tabBarOnly)
    }
}
