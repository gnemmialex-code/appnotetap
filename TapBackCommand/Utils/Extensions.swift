//
//  Extensions.swift
//  TapBack Command
//
//  Small, shared conveniences.
//

import SwiftUI

extension Date {
    /// Short, locale-aware relative-ish label, e.g. "Aujourd'hui 14:32".
    var shortStamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        if Calendar.current.isDateInToday(self) {
            formatter.dateFormat = "'Aujourd''hui' HH:mm"
        } else if Calendar.current.isDateInYesterday(self) {
            formatter.dateFormat = "'Hier' HH:mm"
        } else {
            formatter.dateFormat = "d MMM HH:mm"
        }
        return formatter.string(from: self)
    }
}

extension TimeInterval {
    /// mm:ss formatting for timers.
    var clockString: String {
        let total = Int(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

extension View {
    /// Applies a translucent material card style consistent with the design.
    func glassCard(cornerRadius: CGFloat = Constants.Layout.buttonCorner) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    /// Hides the keyboard from anywhere.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
}
