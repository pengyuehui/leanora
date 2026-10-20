import SwiftUI

@main
struct LeanoraApp: App {
    @State private var preferences: AppPreferences
    @State private var health: HealthAuthorizationService
    @State private var notifications: NotificationPermissionService
    @State private var store: DataStoreController

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
                else if preferences.hasCompletedOnboarding, let training = store.training { MainTabView().environment(training) }
                else { OnboardingView() }
            }
            .environment(preferences)
            .environment(health)
            .environment(notifications)
            .environment(store)
            .task { await store.start(preferences: preferences) }
            .onChange(of: preferences.values) { _, values in Task { await store.synchronize(values) } }
            .tint(LeanoraTheme.accent)
            #if DEBUG
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--uitesting")
                                  && ProcessInfo.processInfo.arguments.contains("--dark-mode") ? .dark : nil)
            #endif
        }
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
