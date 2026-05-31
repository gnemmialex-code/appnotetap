//
//  ReminderService.swift
//  TapBack Command
//
//  Schedules local iOS reminders for to-dos. Uses UserNotifications for a
//  zero-friction local alert, and optionally mirrors the reminder into the
//  system Reminders app via EventKit when the user grants access.
//

import Foundation
import UserNotifications
import EventKit

final class ReminderService {

    static let shared = ReminderService()
    private let store = EKEventStore()
    private init() {}

    // MARK: - Local notification

    func requestNotificationPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
        }
    }

    /// Schedules a local notification. Returns the request identifier so the
    /// caller can store it for later cancellation.
    @discardableResult
    func scheduleNotification(text: String, at date: Date) async -> String? {
        guard await requestNotificationPermission() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Rappel"
        content.body = text
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            return id
        } catch {
            return nil
        }
    }

    func cancelNotification(id: String?) {
        guard let id else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Convenience: "rappelle-moi demain 9h".
    static func tomorrowAt9() -> Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    // MARK: - EventKit mirror (optional)

    func addToSystemReminders(text: String, at date: Date) async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            granted = await withCheckedContinuation { cont in
                store.requestAccess(to: .reminder) { ok, _ in cont.resume(returning: ok) }
            }
        }
        guard granted else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = text
        reminder.calendar = store.defaultCalendarForNewReminders()
        reminder.addAlarm(EKAlarm(absoluteDate: date))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        reminder.dueDateComponents = comps

        do { try store.save(reminder, commit: true); return true }
        catch { return false }
    }
}
