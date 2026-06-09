//
//  SettingsGuideView.swift
//  TapBack Command
//
//  Vue d'aide en français expliquant comment configurer Toucher le dos.
//  Affichez-la depuis n'importe quelle vue existante, par exemple :
//
//    .sheet(isPresented: $showGuide) { SettingsGuideView() }
//
//  ou intégrez-la dans votre BackTapOnboardingView si vous le souhaitez.
//
//  ── Ce que cette vue ne fait PAS ─────────────────────────────────────────
//  iOS n'autorise aucune app tierce à ouvrir directement le panneau
//  Accessibilité → Toucher le dos, ni à le configurer automatiquement.
//  UIApplication.openSettingsURLString ouvre uniquement les Réglages de
//  l'application elle-même, pas le sous-menu Accessibilité.
//  L'utilisateur doit naviguer manuellement jusqu'à Toucher le dos.
//

import SwiftUI

struct SettingsGuideView: View {

    // Fermez la feuille depuis l'extérieur si besoin (optionnel).
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Titre ────────────────────────────────────────────
                    Text("Configurer Toucher le dos")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    // ── Étapes ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        stepView(number: "1",
                                 text: "Ouvrez **Réglages → Accessibilité → Toucher → Toucher le dos**.")
                        stepView(number: "2",
                                 text: "Choisissez **Double‑tap** (ou **Triple‑tap**).")
                        stepView(number: "3",
                                 text: "Sélectionnez **Raccourci** puis choisissez le raccourci nommé **« Ouvrir la petite fenêtre »** fourni par l'application.")
                        stepView(number: "4",
                                 text: "Revenez dans l'app et testez en **tapant deux fois l'arrière** de votre iPhone.")
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.15))

                    // ── Note importante ───────────────────────────────────
                    Label {
                        Text("iOS ne permet pas à une application d'ouvrir directement le panneau Toucher le dos. Suivez les étapes ci-dessus manuellement.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // ── Bouton Réglages ───────────────────────────────────
                    // Ouvre les Réglages de l'app (point de départ pratique).
                    // ⚠️  UIApplication.openSettingsURLString mène aux réglages
                    //     de l'app, pas directement à Toucher le dos.
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Aller aux Réglages", systemImage: "gear")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .background(Constants.Palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stepView(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.callout.bold())
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())

            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SettingsGuideView()
}
