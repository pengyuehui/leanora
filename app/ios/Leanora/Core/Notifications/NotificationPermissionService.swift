import Observation
import UserNotifications

enum NotificationAccess: Equatable { case unknown, notDetermined, allowed, denied, failed }

@MainActor
protocol NotificationAuthorizing {
    func status() async -> NotificationAccess
    func request() async throws -> Bool
}

@MainActor
final class SystemNotificationAuthorizer: NotificationAuthorizing {
    func status() async -> NotificationAccess {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }
    func request() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}

@MainActor @Observable
final class NotificationPermissionService {
    private let authorizer: any NotificationAuthorizing
    private var operation = 0
    private(set) var access: NotificationAccess = .unknown
    private(set) var isRequesting = false
    init(authorizer: any NotificationAuthorizing = SystemNotificationAuthorizer()) { self.authorizer = authorizer }
    func refresh() async {
        guard !isRequesting else { return }
        operation += 1
        let current = operation
        let status = await authorizer.status()
        if current == operation { access = status }
    }
    func request() async {
        guard !isRequesting else { return }
        operation += 1
        isRequesting = true
        defer { isRequesting = false }
        do { access = try await authorizer.request() ? .allowed : .denied }
        catch { access = .failed }
    }
}
