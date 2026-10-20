import Foundation
import UserNotifications

@MainActor final class TrainingReminderService {
    private var pending: [WorkoutReminder]?
    private var updating = false
    static func upcoming(templates: [WorkoutTemplate], changes: [WorkoutDayChange], sessions: [WorkoutSession], hour: Int, minute: Int, now: Date = Date(), calendar: Calendar = .current) -> [WorkoutReminder] {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return [] }
        return (0..<14).compactMap { offset -> WorkoutReminder? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), date > now else { return nil }
            let localDate = RecordMoment(date, timeZoneID: calendar.timeZone.identifier).localDate
            let occurrences = TrainingPlan.occurrences(on: localDate, templates: templates, changes: changes).filter { occurrence in
                !sessions.contains { $0.stamp.deletedAt == nil && $0.status != .abandoned && $0.templateID == occurrence.template.stamp.id && $0.scheduleOriginDate == occurrence.originDate }
            }
            guard !occurrences.isEmpty else { return nil }
            return WorkoutReminder(id: "leanora.plan.\(localDate)", deadline: date, title: "今天有训练安排，按自己的节奏开始吧。")
        }
    }
    func schedule(_ reminders: [WorkoutReminder]) async throws {
        pending = reminders; guard !updating else { return }
        updating = true; defer { updating = false }
        while let desired = pending { pending = nil; try await replace(desired) }
    }
    private func replace(_ reminders: [WorkoutReminder]) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("leanora.plan.") }.map(\.identifier))
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for reminder in reminders where reminder.deadline > Date() {
            let content = UNMutableNotificationContent(); content.title = "Leanora"; content.body = reminder.title; content.sound = .default
            try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.deadline.timeIntervalSinceNow), repeats: false)))
        }
    }
}
