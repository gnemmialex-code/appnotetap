//
//  TodoViewModel.swift
//  TapBack Command
//

import Foundation
import SwiftUI

@MainActor
final class TodoViewModel: ObservableObject {

    @Published private(set) var todos: [Todo] = []

    private let storage = StorageService.shared
    private let reminders = ReminderService.shared

    init() { load() }

    func load() {
        todos = storage.loadTodos().sorted { $0.createdAt > $1.createdAt }
    }

    /// Adds a to-do in "1 second", optionally scheduling a reminder.
    func add(text: String, reminderDate: Date? = nil) {
        guard !text.isBlank else { return }
        var todo = Todo(text: text.trimmed, reminderDate: reminderDate)

        if let date = reminderDate {
            Task {
                let id = await reminders.scheduleNotification(text: todo.text, at: date)
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].notificationID = id
                    persist()
                }
            }
        }

        todos.insert(todo, at: 0)
        Haptics.shared.impact(.light)
        persist()
    }

    func toggleDone(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isDone.toggle()
        Haptics.shared.selection()
        persist()
    }

    func delete(_ todo: Todo) {
        reminders.cancelNotification(id: todo.notificationID)
        todos.removeAll { $0.id == todo.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        offsets.map { todos[$0] }.forEach { reminders.cancelNotification(id: $0.notificationID) }
        todos.remove(atOffsets: offsets)
        persist()
    }

    private func persist() { storage.saveTodos(todos) }
}
