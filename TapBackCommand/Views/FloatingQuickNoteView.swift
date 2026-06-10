//
//  FloatingQuickNoteView.swift
//  TapBack Command
//
//  Petite fenêtre blanche professionnelle qui SORT VISUELLEMENT DE L'ENCOCHE
//  (Dynamic Island / notch) en glissant depuis le haut de l'écran.
//
//  Déclenchée par :
//    • OpenQuickNoteIntent  (Back Tap / raccourci Siri)
//    • URL scheme           tapbackcommand://openQuickNote
//    • Appel direct         QuickNoteManager.shared.presentFloatingWindow()
//
//  ── Effet "sortie d'encoche" ──────────────────────────────────────────────
//  • Le panneau est collé au bord supérieur PHYSIQUE de l'écran : son fond
//    blanc remonte SOUS l'encoche grâce à .ignoresSafeArea(edges: .top)
//    appliqué à la forme de fond uniquement.
//  • Seuls les coins INFÉRIEURS sont arrondis (UnevenRoundedRectangle),
//    pour donner l'impression que le panneau émerge du haut de l'iPhone.
//  • Le contenu, lui, reste DANS la safe area : rien n'est masqué par
//    l'encoche.
//  • Le reste de l'écran est grisé (scrim) : seule la fenêtre compte.
//  • Animation spring : le panneau glisse depuis le haut (offset négatif → 0).
//
//  ── Lien avec Premium ─────────────────────────────────────────────────────
//  • Utilisateur PREMIUM     → fenêtre complète (note + actions rapides).
//  • Utilisateur NON premium → version limitée : la note texte simple reste
//    utilisable, les actions avancées (Vocal / To-Do / Capture) sont
//    verrouillées et ouvrent PremiumPaywallView.
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
    @ObservedObject private var premium = PremiumManager.shared
    @EnvironmentObject private var notesVM: NotesViewModel

    @State private var noteText = ""
    @State private var appeared = false
    @State private var showPaywall = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {

            // ── Scrim plein écran ─────────────────────────────────────────
            // Fond légèrement grisé : met le panneau en avant et intercepte
            // les taps en dehors pour fermer.
            // opacity minimale > 0 + contentShape : garantit que la zone
            // reste tappable même pendant l'animation d'apparition.
            Color.black.opacity(appeared ? 0.35 : 0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { performDismiss() }

            // ── Panneau blanc "sortant de l'encoche" ──────────────────────
            QuickNotePanel(
                noteText:   $noteText,
                focused:    $focused,
                isPremium:  premium.isPremium,
                onSave:     saveAndDismiss,
                onDismiss:  performDismiss,
                onLocked:   { showPaywall = true }   // action verrouillée → paywall
            )
            .frame(maxWidth: .infinity)
            // Le fond blanc remonte sous l'encoche ; le contenu reste dans
            // la safe area. Coins arrondis en bas SEULEMENT : le panneau
            // semble émerger du haut physique de l'iPhone.
            .background(alignment: .top) {
                UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 28, bottomTrailing: 28),
                    style: .continuous
                )
                .fill(Color.white)
                .ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(0.20), radius: 30, x: 0, y: 14)
            }
            // Animation slide-down : part hors écran (au-dessus de l'encoche)
            // et descend jusqu'à sa position finale.
            .offset(y: appeared ? 0 : -420)
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
        // Paywall présenté quand l'utilisateur non-premium touche une
        // fonctionnalité avancée.
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
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
    let isPremium: Bool
    let onSave:    () -> Void
    let onDismiss: () -> Void
    let onLocked:  () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── En-tête ───────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Note rapide")
                    .font(.tbcHeadline)
                    .foregroundStyle(.black)
                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.45))
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
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
                .padding(.horizontal, 20)
                .focused($focused)
                .onSubmit { onSave() }

            // ── Barre d'actions ───────────────────────────────────────────
            // Premium : actions actives. Non-premium : verrouillées → paywall.
            HStack(spacing: 6) {
                ActionChip(icon: "mic.fill",  label: "Vocal",   tint: Constants.Palette.record,
                           locked: !isPremium, action: isPremium ? onDismiss : onLocked)
                ActionChip(icon: "checklist", label: "To-Do",   tint: .black,
                           locked: !isPremium, action: isPremium ? onDismiss : onLocked)
                ActionChip(icon: "sparkles",  label: "Capture", tint: .black,
                           locked: !isPremium, action: isPremium ? onDismiss : onLocked)
                Spacer()
                SaveButton(
                    disabled: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action:   onSave
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // ── Bandeau Premium (non-premium uniquement) ──────────────────
            if !isPremium {
                Button(action: onLocked) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Version gratuite — débloquer toutes les actions")
                            .font(.tbcCaptionSmall)
                    }
                    .foregroundStyle(.black.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.05), in: Capsule())
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }

            // ── Drag handle (en bas : on tire / swipe vers le haut) ───────
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 10)
        }
        // Swipe vers le haut = fermeture (le panneau "rentre" dans l'encoche).
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
    var locked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.tbcCaption)
            }
            .foregroundStyle(locked ? Color.black.opacity(0.35) : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                (locked ? Color.black.opacity(0.30) : tint).opacity(0.10),
                in: Capsule()
            )
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

#Preview("Panneau sortant de l'encoche") {
    ZStack {
        Color.black.ignoresSafeArea()
        FloatingQuickNoteView()
            .environmentObject(NotesViewModel())
    }
}
