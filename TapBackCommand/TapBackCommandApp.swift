//
//  TapBackCommandApp.swift
//  TapBack Command
//
//  App entry point. Wires up the shared stores, the root view and the
//  Back-Tap routing logic. When the app is launched (or resumed) by the
//  "OpenTapBackCommand" App Intent, `AppRouter.showFloatingCommand` flips
//  to true and the floating overlay slides down from the top.
//
//  ── Ajouts Back Tap / URL scheme ─────────────────────────────────────────
//  • QuickNoteManager.shared est initialisé ici pour que son observateur
//    de notification .openQuickNote soit actif dès le cold start.
//  • .onOpenURL gère le scheme tapbackcommand:// (fallback iOS < 16 ou
//    raccourci "Ouvrir URL" dans l'app Raccourcis).
//
//  ⚠️  iOS n'autorise PAS l'automatisation de la configuration de
//      Toucher le dos depuis une app tierce. L'utilisateur doit le faire
//      manuellement : Réglages → Accessibilité → Toucher → Toucher le dos.
//

import SwiftUI

@main
struct TapBackCommandApp: App {

    // Shared, app-wide state. Injected into the environment so any view
    // (and the App Intent perform handler) can reach the same instances.
    @StateObject private var router = AppRouter.shared
    @StateObject private var notesVM = NotesViewModel()
    @StateObject private var todoVM = TodoViewModel()
    @StateObject private var captureVM = CaptureViewModel()

    // Initialise QuickNoteManager au démarrage pour activer l'observateur
    // .openQuickNote avant tout cold start via URL scheme ou App Intent.
    // ⚠️  Ne retirez pas cette ligne : sans elle, la notification postée lors
    //     d'un cold start URL serait perdue avant que le manager ne s'abonne.
    @StateObject private var quickNoteManager = QuickNoteManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(notesVM)
                .environmentObject(todoVM)
                .environmentObject(captureVM)
                .preferredColorScheme(.dark)
                // ── URL scheme fallback ────────────────────────────────────
                // Gère tapbackcommand://openQuickNote (raccourci "Ouvrir URL"
                // dans Raccourcis, deep link externe, ou iOS < 16 sans AppIntents).
                .onOpenURL { handleIncomingURL($0) }
        }
    }

    // MARK: - URL scheme handler

    /// Traite les URL entrantes du scheme `tapbackcommand://`.
    ///
    /// URL valide   : tapbackcommand://openQuickNote
    /// URLs ignorées (silencieusement, sans crash) :
    ///   • schéma inconnu  : https://example.com
    ///   • host inconnu    : tapbackcommand://other
    ///   • chemin en trop  : tapbackcommand://openQuickNote/extra
    ///
    /// ── Intégration UIKit (si le projet n'utilise pas SwiftUI) ───────────
    /// Placez cette logique dans AppDelegate :
    ///   func application(_ app: UIApplication,
    ///                    open url: URL,
    ///                    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    ///       guard url.scheme?.lowercased() == "tapbackcommand",
    ///             url.host?.lowercased() == "openquicknote",
    ///             url.pathComponents.filter({ $0 != "/" }).isEmpty else { return false }
    ///       NotificationCenter.default.post(name: .openQuickNote, object: nil)
    ///       return true
    ///   }
    ///
    /// ⚠️  Remplacez "tapbackcommand" si vous changez le scheme dans Info.plist.
    @MainActor
    private func handleIncomingURL(_ url: URL) {
        // 1. Valide le scheme — doit correspondre à CFBundleURLSchemes dans Info.plist.
        guard url.scheme?.lowercased() == "tapbackcommand" else { return }

        // 2. Valide le host (action attendue).
        guard url.host?.lowercased() == "openquicknote" else { return }

        // 3. Aucun composant de chemin supplémentaire attendu.
        //    tapbackcommand://openQuickNote/inconnu → ignoré.
        guard url.pathComponents.filter({ $0 != "/" }).isEmpty else { return }

        // 4. Poste la notification interne. QuickNoteManager.shared l'intercepte
        //    et appelle AppRouter.shared.presentFloatingCommand().
        NotificationCenter.default.post(name: .openQuickNote, object: nil)
    }
}

/// Centralised navigation / overlay state.
///
/// A singleton so the `OpenTapBackCommand` App Intent can toggle the floating
/// command panel from outside the SwiftUI view tree.
@MainActor
final class AppRouter: ObservableObject {

    static let shared = AppRouter()

    /// Controls visibility of the `FloatingCommandView` overlay.
    @Published var showFloatingCommand: Bool = false

    /// The tab currently selected in the root tab view.
    @Published var selectedTab: Tab = .notes

    /// A deep-link action requested by an App Intent (e.g. jump straight
    /// to voice recording).
    @Published var pendingAction: QuickAction? = nil

    enum Tab: Hashable { case notes, todos, captures }

    private init() {}

    /// Called by the App Intent when triggered via Back Tap.
    func presentFloatingCommand() {
        withAnimation(Constants.Animation.overlay) {
            showFloatingCommand = true
        }
        Haptics.shared.impact(.soft)
    }

    func dismissFloatingCommand() {
        withAnimation(Constants.Animation.overlay) {
            showFloatingCommand = false
        }
    }
}

/// Quick actions a Back-Tap / intent can request directly.
enum QuickAction: String, Identifiable {
    case voiceNote
    case todo
    case capture
    var id: String { rawValue }
}
