//
//  QuickNoteManager.swift
//  TapBack Command
//
//  Singleton ObservableObject qui sert de pont public entre :
//    • OpenQuickNoteIntent  (App Intent iOS 16+)
//    • handleIncomingURL    (URL scheme tapbackcommand://openQuickNote)
//    • l'UI existante       (AppRouter.shared.presentFloatingCommand)
//
//  ── API publique ──────────────────────────────────────────────────────────
//  Depuis n'importe quel module, deux façons d'ouvrir la fenêtre :
//
//    // 1. Via notification (découplé, testable, recommandé)
//    NotificationCenter.default.post(name: .openQuickNote, object: nil)
//
//    // 2. Appel direct
//    QuickNoteManager.shared.presentFloatingWindow()
//
//  ── @Published isPresented ───────────────────────────────────────────────
//  L'UI peut observer `isPresented` pour réagir aux changements :
//
//    @ObservedObject var qnm = QuickNoteManager.shared
//    // ou via .onReceive(NotificationCenter.default.publisher(for: .openQuickNote))
//
//  ── Intégration UIKit (si le projet n'utilise pas SwiftUI) ───────────────
//  Observez .openQuickNote dans votre SceneDelegate / AppDelegate :
//
//    NotificationCenter.default.addObserver(
//        forName: .openQuickNote, object: nil, queue: .main) { _ in
//        // Présentez votre UIViewController ici
//    }
//

import Foundation
import Combine
import SwiftUI

// MARK: - Notification.Name

extension Notification.Name {
    /// Notification interne postée par OpenQuickNoteIntent et handleIncomingURL.
    /// Observez-la pour déclencher l'affichage de la fenêtre flottante depuis
    /// n'importe quel module, sans couplage direct à AppRouter.
    ///
    /// ⚠️  Ne renommez pas cet identifiant sans mettre à jour :
    ///     - Info.plist (NSUserActivityTypes)
    ///     - README_BACKTAP.md
    static let openQuickNote = Notification.Name("com.gnemmialex.tapbacknote.openQuickNote")
}

// MARK: - QuickNoteManager

@MainActor
final class QuickNoteManager: ObservableObject {

    static let shared = QuickNoteManager()

    /// Reflète l'état de visibilité de la fenêtre flottante.
    /// Passe à `true` dès que la notification .openQuickNote est reçue ou que
    /// `presentFloatingWindow()` est appelée ; repasse à `false` à la fermeture.
    @Published private(set) var isPresented: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Souscription unique à la notification interne.
        // Toute source (Intent, URL scheme, code tiers) peut poster .openQuickNote
        // sans connaître AppRouter.
        NotificationCenter.default
            .publisher(for: .openQuickNote)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.presentFloatingWindow()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Affiche FloatingQuickNoteView.
    ///
    /// ── Découplé de AppRouter ────────────────────────────────────────────
    /// Ne touche PAS à AppRouter.showFloatingCommand pour éviter que les
    /// deux overlays (FloatingCommandView + FloatingQuickNoteView) s'affichent
    /// simultanément. Chaque overlay a sa propre source de vérité :
    ///   • FloatingCommandView  → AppRouter.shared.showFloatingCommand
    ///   • FloatingQuickNoteView → QuickNoteManager.shared.isPresented
    func presentFloatingWindow() {
        isPresented = true
    }

    /// Ferme FloatingQuickNoteView.
    func dismissFloatingWindow() {
        isPresented = false
    }
}
