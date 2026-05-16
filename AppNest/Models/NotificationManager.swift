import Foundation
import UserNotifications

/// Helper for scheduling and cancelling local reminders for job applications.
enum NotificationManager {

    /// Requests notification authorization from the user.
    /// - Returns: `true` if the user has granted (or previously granted) permission.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    /// Schedules a reminder for the given date. If a reminder with the same id exists, it is replaced.
    /// If `date` is in the past, no reminder is scheduled and the request is removed.
    /// - Returns: The notification identifier that was scheduled, or `nil` if scheduling failed / was skipped.
    @discardableResult
    static func scheduleReminder(
        id: String? = nil,
        title: String,
        body: String,
        date: Date
    ) async -> String? {
        let identifier = id ?? UUID().uuidString
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard date > Date() else { return nil }
        guard await requestAuthorization() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return identifier
        } catch {
            return nil
        }
    }

    /// Cancels a previously scheduled reminder.
    static func cancelReminder(id: String?) {
        guard let id, !id.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Returns `true` if the user has explicitly denied notification permission system-wide.
    static func isDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }
}
