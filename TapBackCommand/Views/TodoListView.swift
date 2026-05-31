//
//  TodoListView.swift
//  TapBack Command
//

import SwiftUI

struct TodoListView: View {

    @EnvironmentObject private var todoVM: TodoViewModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                if todoVM.todos.isEmpty {
                    EmptyState(icon: "checklist",
                               title: "Aucune tâche",
                               message: "Tapote le dos de l'iPhone et choisis ✏️ pour ajouter une tâche.")
                } else {
                    List {
                        ForEach(todoVM.todos) { todo in
                            TodoRow(todo: todo) { todoVM.toggleDone(todo) }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: todoVM.delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("To-Do")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.presentFloatingCommand() } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(.white)
                }
            }
        }
    }
}

private struct TodoRow: View {
    let todo: Todo
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2) // glyphe SF Symbol
                    .foregroundStyle(todo.isDone ? .green : Constants.Palette.secondaryText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.text)
                    .font(.tbcBody)
                    .foregroundStyle(todo.isDone ? .white.opacity(0.4) : .white)
                    .strikethrough(todo.isDone)
                if let date = todo.reminderDate {
                    Label(date.shortStamp, systemImage: "bell.fill")
                        .font(.tbcCaptionSmall)
                        .foregroundStyle(Constants.Palette.secondaryText)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.vertical, 4)
    }
}

#Preview {
    let vm = TodoViewModel()
    vm.add(text: "Rappeler le client", reminderDate: ReminderService.tomorrowAt9())
    vm.add(text: "Envoyer la facture")
    return TodoListView()
        .environmentObject(vm)
        .environmentObject(AppRouter.shared)
        .preferredColorScheme(.dark)
}
