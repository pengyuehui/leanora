import SwiftUI

@main
struct LeanoraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var preferences: AppPreferences
    @State private var health: HealthAuthorizationService
    @State private var notifications: NotificationPermissionService
    @State private var store: DataStoreController
    @State private var trainingReminderService = TrainingReminderService()

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") {
            _store = State(initialValue: DataStoreController(testing: true, reset: arguments.contains("--reset-state")))
            let defaults = UserDefaults(suiteName: "Leanora.UITesting")!
            if arguments.contains("--reset-state") { defaults.removePersistentDomain(forName: "Leanora.UITesting") }
            _preferences = State(initialValue: AppPreferences(defaults: defaults))
            if arguments.contains("--system-permissions") {
                _health = State(initialValue: HealthAuthorizationService())
                _notifications = State(initialValue: NotificationPermissionService())
            } else {
                _health = State(initialValue: HealthAuthorizationService(authorizer: UITestHealthAuthorizer(arguments: arguments)))
                _notifications = State(initialValue: NotificationPermissionService(authorizer: UITestNotificationAuthorizer(arguments: arguments)))
            }
            return
        }
        #endif
        _store = State(initialValue: DataStoreController())
        _preferences = State(initialValue: AppPreferences())
        _health = State(initialValue: HealthAuthorizationService())
        _notifications = State(initialValue: NotificationPermissionService())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = store.startupError {
                    StoreUnavailableView(message: error)
                } else if store.repository == nil { ProgressView("正在打开本机资料库…") }
                else if preferences.hasCompletedOnboarding, let training = store.training, let journal = store.journal { MainTabView().environment(training).environment(journal) }
                else { OnboardingView() }
            }
            .environment(preferences)
            .environment(health)
            .environment(notifications)
            .environment(store)
            .task { await store.start(preferences: preferences) }
            .onChange(of: preferences.values) { _, values in Task { await store.synchronize(values) } }
            .task(id: "\(preferences.trainingRemindersEnabled)-\(preferences.trainingReminderHour)-\(preferences.trainingReminderMinute)-\(store.training?.dataVersion ?? 0)") { await updateTrainingReminders() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.training?.refresh(); await store.journal?.refresh(); await updateTrainingReminders() } }
            }
            .tint(LeanoraTheme.accent)
            #if DEBUG
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--uitesting")
                                  && ProcessInfo.processInfo.arguments.contains("--dark-mode") ? .dark : nil)
            #endif
        }
    }
    private func updateTrainingReminders() async {
        guard let training = store.training else { return }
        let reminders = preferences.trainingRemindersEnabled ? TrainingReminderService.upcoming(templates: training.templates, changes: training.changes, sessions: training.sessions, hour: preferences.trainingReminderHour, minute: preferences.trainingReminderMinute) : []
        do { try await trainingReminderService.schedule(reminders) }
        catch { training.error = "训练提醒暂未安排，请在通知设置中重试。" }
    }
}

#if DEBUG
// Test-only adapters are activated by an explicit UI-test launch argument.
// Release builds always use Apple frameworks and never infer read authorization.
@MainActor final class UITestHealthAuthorizer: HealthAuthorizing {
    private let arguments: [String]
    init(arguments: [String]) { self.arguments = arguments }
    var isAvailable: Bool { !arguments.contains("--health-unavailable") }
    func request(_ selection: HealthAccessSelection) async throws {
        if arguments.contains("--health-failed") { throw CocoaError(.userCancelled) }
    }
    func writableCount(_ selection: HealthAccessSelection) -> Int { 0 }
}

@MainActor final class UITestNotificationAuthorizer: NotificationAuthorizing {
    private let arguments: [String]
    init(arguments: [String]) { self.arguments = arguments }
    func status() async -> NotificationAccess { .notDetermined }
    func request() async throws -> Bool { !arguments.contains("--notifications-denied") }
}
#endif
