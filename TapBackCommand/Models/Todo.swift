//
//  Todo.swift
//  TapBack Command
//
//  A lightweight to-do that can optionally schedule a local iOS reminder
//  (UNUserNotification) and/or an EventKit reminder.
//

import Foundation

struct Todo: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var text: String
    var isDone: Bool
    /// When set, a local notification is scheduled for this date.
    var reminderDate: Date?
    /// Identifier of the scheduled UNNotificationRequest, for cancellation.
    var notificationID: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        text: String,
        isDone: Bool = false,
        reminderDate: Date? = nil,
        notificationID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.isDone = isDone
        self.reminderDate = reminderDate
        self.notificationID = notificationID
    }

    var hasReminder: Bool { reminderDate != nil }
}

extension Todo {
    static let preview = Todo(text: "Rappeler le client à propos du devis",
                              reminderDate: Calendar.current.date(byAdding: .day, value: 1, to: .now))
}
