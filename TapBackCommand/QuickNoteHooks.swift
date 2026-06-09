//
//  QuickNoteHooks.swift
//  TapBack Command
//
//  Exemples de hooks publics utilisables depuis n'importe quel module
//  pour déclencher ou observer la fenêtre flottante sans couplage direct
//  à AppRouter ou à QuickNoteManager.
//
//  Ce fichier est OPTIONNEL. Il n'est pas nécessaire au fonctionnement de
//  l'App Intent ou du URL scheme. Copiez uniquement les snippets utiles.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Hook 1 : Notification directe (le plus simple)

/// Ouvre la fenêtre flottante depuis n'importe où dans l'app ou
/// depuis une extension (Widget, Intent, etc.) :
///
///   NotificationCenter.default.post(name: .openQuickNote, object: nil)
///
/// C'est le hook recommandé car il ne crée aucune dépendance de compilation
/// vers AppRouter ou QuickNoteManager.

// MARK: - Hook 2 : Appel direct au singleton

/// Quand vous avez accès au main actor (ex. dans une View, un ViewModel) :
///
///   await MainActor.run {
///       QuickNoteManager.shared.presentFloatingWindow()
///   }
///
/// Ou depuis un contexte @MainActor :
///
///   QuickNoteManager.shared.presentFloatingWindow()

// MARK: - Hook 3 : Observer SwiftUI (@ObservedObject)

/// Dans une View qui doit réagir à l'état isPresented :
///
///   @ObservedObject private var qnm = QuickNoteManager.shared
///
///   var body: some View {
///       Text(qnm.isPresented ? "Ouvert" : "Fermé")
///   }

// MARK: - Hook 4 : Publisher Combine (pour UIKit / ViewModel)

/// Dans un UIViewController ou un ViewModel ObservableObject :
///
///   private var cancellables = Set<AnyCancellable>()
///
///   func startObserving() {
///       NotificationCenter.default
///           .publisher(for: .openQuickNote)
///           .receive(on: RunLoop.main)
///           .sink { [weak self] _ in
///               self?.handleQuickNoteOpened()
///           }
///           .store(in: &cancellables)
///   }

// MARK: - Hook 5 : onReceive SwiftUI

/// Dans une View SwiftUI qui veut réagir à chaque ouverture :
///
///   .onReceive(NotificationCenter.default.publisher(for: .openQuickNote)) { _ in
///       // réaction locale à l'ouverture
///   }

// MARK: - Hook 6 : Ouvrir via URL (deep link externe ou test rapide)

/// Depuis Safari, un autre app, ou xcrun simctl :
///
///   URL valide  : tapbackcommand://openQuickNote
///   URL invalide: tapbackcommand://other          → ignorée sans crash
///   URL invalide: https://example.com             → ignorée sans crash
///
///   // Test depuis le terminal (simulateur) :
///   // xcrun simctl openurl booted "tapbackcommand://openQuickNote"

// MARK: - Vérification rapide (script CLI)

/// Pour vérifier que OpenQuickNoteIntent est présent dans le code source :
///
///   rg "OpenQuickNoteIntent" --type swift
///
/// Résultat attendu :
///   TapBackCommand/Intents/OpenQuickNoteIntent.swift
///   TapBackCommand/TapBackCommandApp.swift  (aucun — il est dans Info.plist via NSUserActivityTypes)
///
/// Pour vérifier que le scheme est déclaré :
///   rg "tapbackcommand" --type plist
