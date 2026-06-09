//
//  FloatingQuickNoteView.swift
//  TapBack Command
//
//  Vue "petite fenêtre flottante" déclenchée par :
//    • OpenQuickNoteIntent  (Back Tap / raccourci Siri)
//    • URL scheme           tapbackcommand://openQuickNote
//    • Appel direct         QuickNoteManager.shared.presentFloatingWindow()
//
//  ── Comportement visuel ───────────────────────────────────────────────────
//  • Occupe tout l'écran mais ne dessine QUE le panneau blanc en haut.
//  • Le reste de l'écran est transparent (Color.black.opacity(0.001)) et
//    intercepte les taps pour fermer le panneau.
//  • Slide-down + spring depuis le haut à l'ouverture.
//  • Swipe vers le haut OU tap en dehors du panneau = fermeture.
//
//  ── Intégration ───────────────────────────────────────────────────────────
//  Ajoutée comme overlay dans RootView.swift (zIndex 20).
//  Aucune modification de l'UI existante (FloatingCommandView reste intact).
//
//  ⚠️  Nécessite que NotesViewModel soit dans l'environment (fait dans
//      TapBackCommandApp via .environmentObject(notesVM)).
//

import SwiftUI

// MARK: - FloatingQuickNoteView (vue publique)

struct FloatingQuickNoteView: View {

    @ObservedObject private var manager = QuickNoteManager.shared
    @EnvironmentObject  private var notesVM: NotesViewModel

    @State  private var noteText  = ""
    @State  private var appeared  = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {

            // ── Fond plein-écran transparent ─────────────────────────────
            // opacity > 0 est OBLIGATOIRE pour que SwiftUI intercepte les taps.
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { performDismiss() }

            // ── Panneau blanc flottant ────────────────────────────────────
            QuickNotePanel(
                noteText: $noteText,
                focused:  $focused,
                onSave:   saveAndDismiss,
                onDismiss: performDismiss
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Animation slide-down : part de -260 (hors écran) vers 0.
            .offset(y: appeared ? 0 : -260)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Haptics.shared.impact(.soft)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                appeared = true
            }
            // Petit délai pour que le clavier n'apparaisse pas avant le panneau.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                focused = true
            }
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            performDismiss()
            return
        }
        notesVM.add(Note(
            transcript: trimmed,
            summary:    String(trimmed.prefix(120)),
            title:      String(trimmed.prefix(50).components(separatedBy: .newlines).first ?? trimmed)
        ))
        Haptics.shared.notify(.success)
        performDismiss()
    }

    /// Anime la sortie du panneau AVANT de mettre isPresented à false,
    /// pour que SwiftUI ne retire pas la vue brusquement.
    private func performDismiss() {
        focused = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            manager.dismissFloatingWindow()
        }
    }
}

// MARK: - QuickNotePanel (vue interne)

private struct QuickNotePanel: View {

    @Binding var noteText: String
    @FocusState.Binding var focused: Bool
    let onSave:    () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── Drag handle ───────────────────────────────────────────────
            Capsule()
                .fill(Color.black.opacity(0.10))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 12)

            // ── En-tête ───────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Note rapide")
                    .font(.tbcHeadline)
                    .foregroundStyle(.black)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // ── Champ de texte ────────────────────────────────────────────
            TextField("Écris ta note ici…", text: $noteText, axis: .vertical)
                .lineLimit(2...4)
                .font(.tbcBody)
                .foregroundStyle(.black)
                .padding(12)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(.horizontal, 16)
                .focused($focused)
                // Valider avec ⌘↩ sur clavier physique.
                .onSubmit { onSave() }

            // ── Barre d'actions ───────────────────────────────────────────
            HStack(spacing: 6) {
                ActionChip(icon: "mic.fill",   label: "Vocal",   tint: Constants.Palette.record,  action: onDismiss)
                ActionChip(icon: "checklist",  label: "To-Do",   tint: Constants.Palette.accent,  action: onDismiss)
                ActionChip(icon: "sparkles",   label: "Capture", tint: Constants.Palette.accent,  action: onDismiss)
                Spacer()
                SaveButton(
                    disabled: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action:   onSave
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        // Panneau blanc avec coins arrondis (bas seulement pour l'effet "collé en haut")
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 28, x: 0, y: 14)
        // Swipe vers le haut = fermeture.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { v in if v.translation.height < -20 { onDismiss() } }
        )
    }
}

// MARK: - Composants internes

private struct ActionChip: View {
    let icon:   String
    let label:  String
    let tint:   Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.tbcCaption)
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SaveButton: View {
    let disabled: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Text("Enregistrer")
                .font(.tbcCaption)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    disabled
                        ? Color.black.opacity(0.25)
                        : Color.black,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.15), value: disabled)
    }
}

// MARK: - Preview

#Preview("Panneau flottant") {
    ZStack {
        Color.black.ignoresSafeArea()
        FloatingQuickNoteView()
            .environmentObject(NotesViewModel())
    }
}
