//
//  PremiumManager.swift
//  TapBack Command
//
//  Façade "métier" au-dessus de StoreManager.
//
//  ── API publique ──────────────────────────────────────────────────────────
//    PremiumManager.shared.isPremium          // Bool, observable
//    await PremiumManager.shared.refreshAtLaunch()   // au lancement
//    await PremiumManager.shared.restorePurchases()  // bouton "Restaurer"
//
//  ── Pourquoi deux couches ? ───────────────────────────────────────────────
//  • StoreManager  = plomberie StoreKit 2 (peut changer, être testée à part).
//  • PremiumManager = état métier simple + cache UserDefaults pour que
//    l'UI connaisse l'état premium INSTANTANÉMENT au cold start, avant même
//    que StoreKit ait répondu (évite un "flash" du paywall au lancement).
//
//  ⚠️  Le cache UserDefaults est un confort d'affichage, PAS une preuve
//      d'achat : la source de vérité reste Transaction.currentEntitlements,
//      revalidée à chaque lancement via refreshAtLaunch().
//

import Foundation
import Combine
import SwiftUI
import StoreKit // expose le type `Product` dans l'API publique

@MainActor
final class PremiumManager: ObservableObject {

    static let shared = PremiumManager()

    // MARK: - Clé de persistance

    /// Clé UserDefaults du cache premium. Préfixée par le bundle ID existant
    /// pour éviter toute collision — ne modifie pas le bundle ID lui-même.
    private static let storageKey = "com.gnemmialex.tapbacknote.isPremiumCached"

    // MARK: - État observable

    /// `true` si l'utilisateur est premium.
    ///
    /// Initialisé depuis le cache UserDefaults (réponse instantanée au
    /// lancement), puis tenu à jour en continu par StoreManager.
    @Published private(set) var isPremium: Bool

    /// Relais des états de StoreManager pour l'UI (paywall).
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Privé

    private let store = StoreManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 1. Lecture synchrone du cache : l'UI a une valeur dès la frame 0.
        isPremium = UserDefaults.standard.bool(forKey: Self.storageKey)

        // 2. StoreManager devient la source de vérité dès qu'il a répondu :
        //    chaque changement met à jour l'état publié ET le cache.
        store.$isPremium
            .dropFirst() // ignore la valeur initiale (false) avant la 1re vérif
            .receive(on: RunLoop.main)
            .sink { [weak self] premium in
                self?.isPremium = premium
                UserDefaults.standard.set(premium, forKey: Self.storageKey)
            }
            .store(in: &cancellables)

        // 3. Relais des états de chargement / erreur pour le paywall.
        store.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)

        store.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)
    }

    // MARK: - API publique

    /// Revalide l'état premium auprès de StoreKit.
    ///
    /// À appeler au lancement de l'app (fait dans TapBackCommandApp via
    /// `.task { await PremiumManager.shared.refreshAtLaunch() }`).
    /// Gère les cas : abonnement expiré, remboursement, achat sur un
    /// autre appareil avec le même compte.
    func refreshAtLaunch() async {
        await store.refreshPurchasedProducts()
    }

    /// Restaure les achats (à brancher sur le bouton "Restaurer les achats").
    func restorePurchases() async {
        await store.restorePurchases()
    }

    /// Achète un produit (relais vers StoreManager, pour que le paywall
    /// n'ait à connaître que PremiumManager).
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        await store.purchase(product)
    }

    /// Produits disponibles (pour le paywall).
    var products: [Product] { store.products }

    /// Produit mis en avant dans le paywall.
    var featuredProduct: Product? { store.featuredProduct }

    /// Recharge la liste des produits (retry après une erreur réseau).
    func reloadProducts() async {
        await store.loadProducts()
    }
}
