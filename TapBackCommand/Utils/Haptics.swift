//
//  Haptics.swift
//  TapBack Command
//
//  Tiny wrapper around UIKit feedback generators. Prepared lazily and
//  reused to keep latency low for the "instant" feel of the overlay.
//

import UIKit

final class Haptics {
    static let shared = Haptics()
    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
