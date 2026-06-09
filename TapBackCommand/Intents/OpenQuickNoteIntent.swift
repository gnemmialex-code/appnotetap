//
//  OpenQuickNoteIntent.swift
//  TapBack Command
//
//  AppIntent iOS 16+ — « Ouvrir la petite fenêtre de note ».
//  Déclare l'action Raccourcis/Siri qui permet au raccourci Back Tap
//  d'afficher la fenêtre flottante de saisie rapide.
//
//  ── Personnalisation ──────────────────────────────────────────────────────
//  • Pour changer le nom affiché dans Raccourcis, modifiez `title` et
//    `description` ci-dessous (LocalizedStringResource).
//  • Pour ajouter une phrase Siri, ajoutez un AppShortcut dans
//    TapBackShortcuts.appShortcuts (BackTapService.swift) :
//
//      AppShortcut(
//          intent: OpenQuickNoteIntent(),
//          phrases: ["Petite fenêtre \(.applicationName)", "Note rapide \(.applicationName)"],
//          shortTitle: "Petite fenêtre",
//          systemImageName: "note.text"
//      )
//
//  ── Capabilities Xcode ───────────────────────────────────────────────────
//  Xcode peut demander d'activer la capability « Siri » sur la cible
//  principale selon votre version. Depuis Xcode 14 / iOS 16, c'est
//  optionnel pour les App Intents simples.
//  Aucun entitlement spécial n'est requis.
//
//  ── Intégration UIKit (si le projet n'utilise pas SwiftUI) ───────────────
//  Dans AppDelegate :
//    NotificationCenter.default.addObserver(
//        self, selector: #selector(openQuickNote),
//        name: .openQuickNote, object: nil)
//
//  @objc private func openQuickNote() {
//      // Présentez votre UIViewController ici.
//  }
//

import AppIntents

// MARK: - OpenQuickNoteIntent

@available(iOS 16.0, *)
struct OpenQuickNoteIntent: AppIntent {

    // ── Remplacez ces chaînes pour localiser l'app ──
    static var title: LocalizedStringResource = "Ouvrir la petite fenêtre de note"
    static var description = IntentDescription(
        "Affiche la mini-fenêtre flottante de TapBack Command pour saisir une note, to-do ou capture en un geste."
    )

    // openAppWhenRun DOIT être true : iOS doit mettre l'app au premier plan
    // pour que la fenêtre flottante s'affiche (iOS n'autorise pas une app
    // tierce à dessiner par-dessus d'autres apps).
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Appel DIRECT pour garantir la livraison au cold start.
        //
        // Pourquoi direct et pas uniquement via notification ?
        // ────────────────────────────────────────────────────
        // Lors d'un cold start iOS, la notification peut être postée avant
        // que QuickNoteManager.shared (initialisé paresseusement par @StateObject
        // dans TapBackCommandApp) n'ait souscrit à NotificationCenter.
        // L'appel direct sur le singleton crée l'instance immédiatement et
        // positionne isPresented = true avant même le premier rendu de RootView.
        // SwiftUI lira isPresented = true dès le premier rendu → overlay visible.
        QuickNoteManager.shared.presentFloatingWindow()

        // On poste aussi la notification pour les observateurs tiers éventuels.
        NotificationCenter.default.post(name: .openQuickNote, object: nil)
        return .result()
    }
}
