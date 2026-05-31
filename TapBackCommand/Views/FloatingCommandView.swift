//
//  FloatingCommandView.swift
//  TapBack Command
//
//  The "Dynamic Island-elargie" command bar: a translucent capsule pinned
//  near the top with three instant actions. Slides down + fades in.
//

import SwiftUI

struct FloatingCommandView: View {

    /// Called with the chosen action.
    let onSelect: (QuickAction) -> Void
    /// Called when the user dismisses (tap outside / swipe up).
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            CommandButton(icon: "mic.fill", label: "Note", tint: Constants.Palette.record) {
                Haptics.shared.impact(.light)
                onSelect(.voiceNote)
            }
            CommandButton(icon: "checklist", label: "To-Do", tint: .white) {
                Haptics.shared.impact(.light)
                onSelect(.todo)
            }
            CommandButton(icon: "sparkles", label: "Capture", tint: .white) {
                Haptics.shared.impact(.light)
                onSelect(.capture)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Constants.Layout.floatingHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        // Swipe up to dismiss.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -20 { onDismiss() }
                }
        )
        .onAppear {
            withAnimation(Constants.Animation.overlay) { appeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Commande rapide TapBack")
    }
}

// MARK: - Single command button

private struct CommandButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold)) // glyphe SF Symbol (taille = mise en page)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.tbcCaptionSmall)
                    .foregroundStyle(Constants.Palette.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Constants.Palette.surface, in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous))
            .scaleEffect(pressed ? 0.93 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(Constants.Animation.button) { pressed = true } }
                .onEnded { _ in withAnimation(Constants.Animation.button) { pressed = false } }
        )
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()
        FloatingCommandView(onSelect: { _ in }, onDismiss: {})
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }
    .preferredColorScheme(.dark)
}
