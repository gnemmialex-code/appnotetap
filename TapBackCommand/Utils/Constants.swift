//
//  Constants.swift
//  TapBack Command
//
//  Central design tokens: colors, sizing, animations and storage keys.
//

import SwiftUI

enum Constants {

    // MARK: - Layout
    enum Layout {
        static let floatingWidthFraction: CGFloat = 0.90
        static let floatingHeight: CGFloat = 80
        static let cornerRadius: CGFloat = 20
        static let buttonCorner: CGFloat = 16
        static let topInset: CGFloat = 8
    }

    // MARK: - Animation
    enum Animation {
        static let overlay: SwiftUI.Animation = .spring(response: 0.42, dampingFraction: 0.82)
        static let waveform: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let button: SwiftUI.Animation = .spring(response: 0.30, dampingFraction: 0.7)
    }

    // MARK: - Palette (noir / blanc / gris translucide)
    enum Palette {
        static let background = Color.black
        static let surface = Color.white.opacity(0.06)
        static let surfaceStrong = Color.white.opacity(0.12)
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.55)
        static let accent = Color.white
        static let record = Color(red: 1.0, green: 0.23, blue: 0.19) // system-ish red
    }

    // MARK: - Recording
    enum Recording {
        static let minDuration: TimeInterval = 1
        static let maxDuration: TimeInterval = 120   // ~2 min
        static let planKeyword = "fais un plan" // trigger phrase
    }

    // MARK: - Storage
    enum Storage {
        static let notesFile = "notes.json"
        static let todosFile = "todos.json"
        static let capturesFile = "captures.json"
        static let audioFolder = "Audio"
        static let imagesFolder = "Images"
    }
}
