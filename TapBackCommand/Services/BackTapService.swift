//
//  BackTapService.swift
//  TapBack Command
//
//  App Intents that Back Tap (via the Shortcuts app) can invoke.
//
//  HOW BACK TAP WORKS ON iOS (and its limits):
//  ────────────────────────────────────────────
//  iOS does NOT let a third-party app draw a floating window over OTHER apps.
//  Back Tap can only run a *Shortcut*. That shortcut can run one of the
//  App Intents below, which opens TapBack Command and shows the floating
//  command overlay *inside our app*.
//
//  USER SETUP (shown in-app on the onboarding screen):
//   1. Open the Shortcuts app → create a shortcut that runs
//      "Ouvrir TapBack Command" (this intent appears automatically).
//   2. Réglages → Accessibilité → Toucher → Toucher le dos de l'appareil
//      → Double Tap (ou Triple) → choisir le raccourci créé.
//   3. Tapote le dos de l'iPhone → l'app s'ouvre directement sur la
//      mini-fenêtre flottante.
//
//  `openAppWhenRun = true` ensures iOS foregrounds the app so the overlay
//  (and recording, which needs the app active) can run.
//

import AppIntents
import SwiftUI

// MARK: - Primary intent: open the floating command panel

struct OpenTapBackCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir TapBack Command"
    static var description = IntentDescription("Affiche la mini-fenêtre flottante avec les 3 actions instantanées.")

    // Bring the app to the foreground when run from Back Tap / Shortcuts.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = nil
        AppRouter.shared.presentFloatingCommand()
        return .result()
    }
}

// MARK: - Direct-action intents (optional shortcuts straight to one action)

struct StartVoiceNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Nouvelle note vocale"
    static var description = IntentDescription("Ouvre TapBack et démarre une note vocale.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .voiceNote
        AppRouter.shared.presentFloatingCommand()
        return .result()
    }
}

struct QuickTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Nouvelle to-do"
    static var description = IntentDescription("Ouvre TapBack et ajoute une to-do.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .todo
        AppRouter.shared.presentFloatingCommand()
        return .result()
    }
}

struct SmartCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture intelligente"
    static var description = IntentDescription("Ouvre TapBack et capture le contexte courant.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .capture
        AppRouter.shared.presentFloatingCommand()
        return .result()
    }
}

// MARK: - Shortcuts provider (makes intents discoverable + Siri phrases)

struct TapBackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTapBackCommandIntent(),
            phrases: [
                "Ouvre \(.applicationName)",
                "Lance \(.applicationName)",
                "Commande \(.applicationName)"
            ],
            shortTitle: "Commande",
            systemImageName: "bolt.circle.fill"
        )
        AppShortcut(
            intent: StartVoiceNoteIntent(),
            phrases: ["Note vocale \(.applicationName)"],
            shortTitle: "Note vocale",
            systemImageName: "mic.circle.fill"
        )
        AppShortcut(
            intent: QuickTodoIntent(),
            phrases: ["Nouvelle tâche \(.applicationName)"],
            shortTitle: "To-Do",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: SmartCaptureIntent(),
            phrases: ["Capture \(.applicationName)"],
            shortTitle: "Capture",
            systemImageName: "sparkles"
        )
    }
}
