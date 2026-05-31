//
//  BackTapOnboardingView.swift
//  TapBack Command
//
//  Step-by-step instructions to wire Back Tap → our App Intent. Presented
//  from a settings/help entry point. Includes a button that deep-links to
//  Settings.
//

import SwiftUI

struct BackTapOnboardingView: View {

    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String, String)] = [
        ("1.circle.fill", "Ouvre Raccourcis",
         "Crée un raccourci qui exécute l'action « Ouvrir TapBack Command »."),
        ("2.circle.fill", "Réglages → Accessibilité",
         "Va dans Toucher → Toucher le dos de l'appareil."),
        ("3.circle.fill", "Double Tap (ou Triple)",
         "Choisis le raccourci TapBack que tu viens de créer."),
        ("4.circle.fill", "Tapote le dos 🎉",
         "L'app s'ouvre directement sur la mini-fenêtre flottante.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Activer le Tap-Back")
                            .font(.tbcLargeTitle)
                            .foregroundStyle(.white)

                        Text("iOS ne permet pas d'afficher une fenêtre par-dessus les autres apps. Le Tap-Back ouvre donc TapBack Command directement sur la commande rapide.")
                            .font(.tbcSubheadline)
                            .foregroundStyle(Constants.Palette.secondaryText)

                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: step.0)
                                    .font(.title2) // glyphe SF Symbol
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.1).font(.tbcHeadline).foregroundStyle(.white)
                                    Text(step.2).font(.tbcSubheadline)
                                        .foregroundStyle(Constants.Palette.secondaryText)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        }

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Ouvrir les Réglages", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(.white, in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    BackTapOnboardingView().preferredColorScheme(.dark)
}
