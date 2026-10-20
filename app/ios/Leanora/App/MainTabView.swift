import SwiftUI

enum AppTab: String, Hashable {
    case today, training, nutrition, trends, settings
}

struct MainTabView: View {
    @State private var selected: AppTab = .today
    var body: some View {
        TabView(selection: $selected) {
            Tab("今天", systemImage: "sun.max", value: .today) {
                NavigationStack { TodayView(selected: $selected) }
            }
            Tab("训练", systemImage: "dumbbell", value: .training) {
                NavigationStack { TrainingHomeView() }
            }
            Tab("饮食", systemImage: "fork.knife", value: .nutrition) {
                NavigationStack { DietDiaryView() }
            }
            Tab("趋势", systemImage: "chart.xyaxis.line", value: .trends) {
                NavigationStack { TrendsView() }
            }
            Tab("我的", systemImage: "person.crop.circle", value: .settings) {
                NavigationStack { SettingsView() }
            }
        }
    }
}
