//
//  PremiumPaywallView.swift
//  TapBack Command
//
//  Paywall présenté quand un utilisateur non-premium tente d'accéder aux
//  fonctionnalités avancées (notamment la fenêtre rapide complète).
//
//  ── Intégration ───────────────────────────────────────────────────────────
//  Présentée en sheet depuis n'importe quelle vue :
//
//      @State private var showPaywall = false
//      ...
//      .sheet(isPresented: $showPaywall) { PremiumPaywallView() }
//
//  Ou conditionnellement avant une fonctionnalité avancée :
//
//      if PremiumManager.shared.isPremium {
//          // fonctionnalité avancée
//      } else {
//          showPaywall = true
//      }
//
//  Design : thème noir/blanc de l'app (Constants.Palette + Typography).
//

import SwiftUI
import StoreKit

struct PremiumPaywallView: View {

    @ObservedObject private var premium = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Bénéfices listés sur le paywall — modifiez librement les textes.
    private let benefits: [(icon: String, text: String)] = [
        ("bolt.fill",        "Fenêtre rapide illimitée"),
        ("note.text",        "Fonctionnalités avancées de notes et to-do"),
        ("mic.fill",         "Notes vocales et captures intelligentes"),
        ("infinity",         "Toutes les futures fonctionnalités Premium"),
    ]

    var body: some View {
        ZStack {
            Constants.Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Bouton fermer ─────────────────────────────────────────
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Constants.Palette.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 12)

                // ── Titre + sous-titre ────────────────────────────────────
                Image(systemName: "crown.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)

                Text("TapBack Premium")
                    .font(.tbcLargeTitle)
                    .foregroundStyle(Constants.Palette.primaryText)

                Text("Débloquez tout le potentiel de vos notes")
                    .font(.tbcSubheadline)
                    .foregroundStyle(Constants.Palette.secondaryText)
                    .padding(.top, 6)

                // ── Liste des bénéfices ───────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(benefits, id: \.text) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: benefit.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Constants.Palette.surfaceStrong, in: Circle())
                            Text(benefit.text)
                                .font(.tbcBody)
                                .foregroundStyle(Constants.Palette.primaryText)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Constants.Palette.surface,
                    in: RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                )
                .padding(.horizontal, 20)
                .padding(.top, 28)

                Spacer()

                // ── Erreur éventuelle ─────────────────────────────────────
                if let error = premium.errorMessage {
                    Text(error)
                        .font(.tbcCaption)
                        .foregroundStyle(Constants.Palette.record)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }

                // ── Prix + bouton d'achat ─────────────────────────────────
                purchaseSection
                    .padding(.horizontal, 20)

                // ── Restaurer les achats ──────────────────────────────────
                Button {
                    Task { await premium.restorePurchases() }
                } label: {
                    Text("Restaurer les achats")
                        .font(.tbcCaption)
                        .foregroundStyle(Constants.Palette.secondaryText)
                        .underline()
                }
                .buttonStyle(.plain)
                .disabled(premium.isLoading)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        // Si l'achat / la restauration aboutit, on ferme le paywall.
        .onChange(of: premium.isPremium) { _, isPremium in
            if isPremium {
                Haptics.shared.notify(.success)
                dismiss()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Section achat

    @ViewBuilder
    private var purchaseSection: some View {
        if let product = premium.featuredProduct {
            VStack(spacing: 10) {
                // Prix localisé fourni par StoreKit (displayPrice gère
                // automatiquement la devise et le format régional).
                Text(priceLabel(for: product))
                    .font(.tbcSubheadline)
                    .foregroundStyle(Constants.Palette.secondaryText)

                Button {
                    Task { await premium.purchase(product) }
                } label: {
                    Group {
                        if premium.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Débloquer Premium")
                                .font(.tbcBodyMedium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(
                        .white,
                        in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(premium.isLoading)
            }
        } else if premium.isLoading {
            // Produits en cours de chargement.
            ProgressView()
                .tint(.white)
                .frame(height: 52)
        } else {
            // Échec de chargement : bouton retry.
            Button {
                Task { await premium.reloadProducts() }
            } label: {
                Text("Recharger les offres")
                    .font(.tbcBodyMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(
                        Constants.Palette.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// Libellé du prix selon le type de produit :
    ///   • abonnement      → "4,99 € / mois"
    ///   • achat unique    → "9,99 € — paiement unique"
    private func priceLabel(for product: Product) -> String {
        if let subscription = product.subscription {
            let unit: String
            switch subscription.subscriptionPeriod.unit {
            case .day:   unit = "jour"
            case .week:  unit = "semaine"
            case .month: unit = "mois"
            case .year:  unit = "an"
            @unknown default: unit = "période"
            }
            return "\(product.displayPrice) / \(unit)"
        }
        return "\(product.displayPrice) — paiement unique"
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PremiumPaywallView()
}
