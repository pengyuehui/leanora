import Foundation
import UserNotifications

struct WorkoutReminder: Equatable, Sendable {
    var id: String
    var deadline: Date
    var title: String
}

@MainActor final class WorkoutNotificationService {
    private var pending: [WorkoutReminder]?
    private var updating = false
    static func reminders(for session: WorkoutSession?, at now: Date) -> [WorkoutReminder] {
        guard let session, [.active, .paused].contains(session.status) else { return [] }
        var values: [WorkoutReminder] = []
        if let deadline = session.restDeadline, deadline > now { values.append(WorkoutReminder(id: "leanora.workout.rest", deadline: deadline, title: "休息结束，可以继续下一组")) }
        if session.status == .active {
            for exercise in session.exercises {
                for set in exercise.sets where set.timerStartedAt != nil && set.completedAt == nil {
                    if let target = exercise.plannedTargets?.durationSeconds {
                        let deadline = now.addingTimeInterval(target - WorkoutEngine.elapsed(set, at: now))
                        if deadline > now { values.append(WorkoutReminder(id: "leanora.workout.set.\(set.id)", deadline: deadline, title: "计时目标已到，请记录实际结果")) }
                    }
                }
            }
        }
        return values
    }
    func replace(_ reminders: [WorkoutReminder]) async throws {
        pending = reminders
        guard !updating else { return }
        updating = true; defer { updating = false }
        while let desired = pending {
            pending = nil
            try await schedule(desired)
        }
    }
    private func schedule(_ reminders: [WorkoutReminder]) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("leanora.workout.") }.map(\.identifier))
        let status = await center.notificationSettings().authorizationStatus
        var allowed = status == .authorized || status == .provisional
        #if os(iOS)
        allowed = allowed || status == .ephemeral
        #endif
        guard allowed else { return }
        for reminder in reminders where reminder.deadline > Date() {
            let content = UNMutableNotificationContent(); content.title = "Leanora"; content.body = reminder.title; content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.deadline.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
