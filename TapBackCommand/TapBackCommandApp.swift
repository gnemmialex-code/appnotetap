//
//  TapBackCommandApp.swift
//  TapBack Command
//
//  App entry point. Wires up the shared stores, the root view and the
//  Back-Tap routing logic. When the app is launched (or resumed) by the
//  "OpenTapBackCommand" App Intent, `AppRouter.showFloatingCommand` flips
//  to true and the floating overlay slides down from the top.
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(notesVM)
                .environmentObject(todoVM)
                .environmentObject(captureVM)
                .preferredColorScheme(.dark)
        }
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
