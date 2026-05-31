//
//  TodoQuickAddView.swift
//  TapBack Command
//
//  One-second to-do entry: a minimal text field + add button, with an
//  optional "rappelle-moi demain 9h" toggle and a custom date picker.
//

import SwiftUI

struct TodoQuickAddView: View {

    /// Called with (text, optional reminder date).
    let onAdd: (String, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var wantsReminder = false
    @State private var reminderDate: Date = ReminderService.tomorrowAt9()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField("Nouvelle tâche…", text: $text, axis: .vertical)
                        .focused($focused)
                        .font(.tbcSubtitleSmall)
                        .foregroundStyle(.white)
                        .padding()
                        .glassCard()
                        .submitLabel(.done)
                        .onSubmit(add)

                    reminderSection

                    Button(action: add) {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                            .font(.tbcHeadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(text.isBlank ? Constants.Palette.surfaceStrong : .white,
                                        in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous))
                            .foregroundStyle(text.isBlank ? .white.opacity(0.4) : .black)
                    }
                    .buttonStyle(.plain)
                    .disabled(text.isBlank)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("To-Do instantanée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
        .onAppear { focused = true }
    }

    private var reminderSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $wantsReminder.animation()) {
                Label("Me rappeler", systemImage: "bell.fill")
                    .foregroundStyle(.white)
            }
            .tint(.white)

            if wantsReminder {
                HStack {
                    Button("Demain 9h") {
                        reminderDate = ReminderService.tomorrowAt9()
                        Haptics.shared.selection()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Constants.Palette.surfaceStrong)

                    Spacer()

                    DatePicker("", selection: $reminderDate,
                               in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
        }
        .padding()
        .glassCard()
    }

    private func add() {
        guard !text.isBlank else { return }
        onAdd(text.trimmed, wantsReminder ? reminderDate : nil)
        Haptics.shared.notify(.success)
        dismiss()
    }
}

#Preview {
    TodoQuickAddView { _, _ in }
        .preferredColorScheme(.dark)
}
