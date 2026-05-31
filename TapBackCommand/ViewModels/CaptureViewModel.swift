//
//  CaptureViewModel.swift
//  TapBack Command
//

import Foundation
import SwiftUI

@MainActor
final class CaptureViewModel: ObservableObject {

    @Published private(set) var captures: [Capture] = []
    @Published var lastCapture: Capture?
    @Published var statusMessage: String?

    private let storage = StorageService.shared
    private let detector = ContextDetectionService.shared

    init() { load() }

    func load() {
        captures = storage.loadCaptures().sorted { $0.createdAt > $1.createdAt }
    }

    /// Attempts a capture from the clipboard context.
    func captureFromContext() {
        if let capture = detector.detectFromPasteboard() {
            store(capture)
            statusMessage = "Capturé : \(capture.kind.label)"
        } else {
            statusMessage = "Rien à capturer. Copiez un lien ou un texte, ou utilisez Partager → TapBack."
            Haptics.shared.notify(.warning)
        }
    }

    func capture(image: UIImage) {
        Task {
            let capture = await detector.capture(fromImage: image)
            store(capture)
            statusMessage = "Photo capturée (\(capture.tags.count) tags)"
        }
    }

    func capture(sharedURL url: URL) {
        store(detector.capture(fromSharedURL: url))
    }

    func capture(sharedText text: String) {
        store(detector.capture(fromSharedText: text))
    }

    func add(_ capture: Capture) { store(capture) }

    func delete(_ capture: Capture) {
        captures.removeAll { $0.id == capture.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        captures.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Private

    private func store(_ capture: Capture) {
        captures.insert(capture, at: 0)
        lastCapture = capture
        Haptics.shared.notify(.success)
        persist()
    }

    private func persist() { storage.saveCaptures(captures) }
}
