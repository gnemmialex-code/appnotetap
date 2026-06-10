//
//  StoreManager.swift
//  TapBack Command
//
//  Couche StoreKit 2 (iOS 16+) : produits, achats, restauration,
//  vérification des transactions et état premium.
//
//  ── Architecture ──────────────────────────────────────────────────────────
//  StoreManager  → parle UNIQUEMENT à StoreKit (Product, Transaction…).
//  PremiumManager → écoute StoreManager, persiste l'état dans UserDefaults
//                   et expose l'API simple `PremiumManager.shared.isPremium`.
//
//  ── À FAIRE PAR VOUS (App Store Connect) ─────────────────────────────────
//  1. Créez vos produits In-App dans App Store Connect (voir README_PREMIUM.md).
//  2. Remplacez les identifiers dans `PremiumProductID` ci-dessous par les
//     vôtres. C'est le SEUL endroit à modifier.
//  ⚠️  Ne changez ni le nom de l'app ni le bundle ID (com.gnemmialex.tapbacknote).
//

import Foundation
import StoreKit

// MARK: - Identifiers produits (⚠️ À PERSONNALISER)

/// Identifiers des produits In-App tels que déclarés dans App Store Connect.
///
/// Convention recommandée : préfixer par le bundle ID existant
/// (`com.gnemmialex.tapbacknote`) SANS jamais modifier le bundle ID lui-même.
/// Remplacez simplement les valeurs ci-dessous par vos identifiers réels.
enum PremiumProductID {

    /// Abonnement auto-renouvelable mensuel.
    static let monthlySubscription = "com.gnemmialex.tapbacknote.premium.monthly"

    /// Achat unique "à vie" (non-consommable).
    static let lifetimeUnlock = "com.gnemmialex.tapbacknote.premium.lifetime"

    /// Tous les identifiers à charger depuis l'App Store.
    /// Ajoutez/retirez librement des entrées : le reste du code s'adapte.
    static let all: Set<String> = [monthlySubscription, lifetimeUnlock]
}

// MARK: - Erreurs

enum StoreError: LocalizedError {
    /// La signature de la transaction n'a pas pu être vérifiée par StoreKit.
    case failedVerification
    /// Aucun produit retourné par l'App Store (identifiers invalides ou
    /// produits pas encore approuvés / configurés dans App Store Connect).
    case productsNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "La vérification de l'achat a échoué. Réessayez."
        case .productsNotFound:
            return "Produits indisponibles. Vérifiez votre connexion et réessayez."
        }
    }
}

// MARK: - StoreManager

@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    // MARK: État observable

    /// Produits récupérés depuis l'App Store, triés par prix croissant.
    /// `product.displayPrice` donne le prix localisé prêt à afficher.
    @Published private(set) var products: [Product] = []

    /// Identifiers des produits actuellement possédés (achat unique non
    /// remboursé, ou abonnement actif).
    @Published private(set) var purchasedProductIDs: Set<String> = []

    /// `true` dès qu'AU MOINS un produit premium est possédé.
    /// PremiumManager écoute cette valeur — ne la lisez pas directement
    /// depuis l'UI, passez par `PremiumManager.shared.isPremium`.
    @Published private(set) var isPremium: Bool = false

    /// `true` pendant le chargement des produits ou un achat en cours.
    @Published private(set) var isLoading: Bool = false

    /// Message d'erreur lisible à afficher dans l'UI (nil = pas d'erreur).
    @Published var errorMessage: String?

    // MARK: Privé

    /// Tâche d'écoute des transactions hors achat direct (renouvellements,
    /// remboursements, achats faits sur un autre appareil, Ask to Buy…).
    /// ⚠️  Doit vivre aussi longtemps que l'app — ne pas l'annuler.
    private var transactionListener: Task<Void, Error>?

    private init() {
        // 1. Démarre l'écoute des transactions AVANT tout le reste,
        //    comme recommandé par Apple (sinon des transactions peuvent
        //    être livrées et perdues au lancement).
        transactionListener = listenForTransactions()

        // 2. Charge les produits + l'état des achats en arrière-plan.
        Task {
            await loadProducts()
            await refreshPurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Chargement des produits

    /// Récupère les `Product` depuis l'App Store pour les identifiers
    /// déclarés dans `PremiumProductID.all`.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: PremiumProductID.all)
            guard !storeProducts.isEmpty else {
                errorMessage = StoreError.productsNotFound.errorDescription
                return
            }
            // Tri par prix croissant pour un affichage stable dans le paywall.
            products = storeProducts.sorted { $0.price < $1.price }
            errorMessage = nil
        } catch {
            errorMessage = "Impossible de charger les produits : \(error.localizedDescription)"
        }
    }

    /// Produit "principal" mis en avant dans le paywall.
    /// Par défaut : l'achat à vie s'il existe, sinon le premier produit.
    var featuredProduct: Product? {
        products.first { $0.id == PremiumProductID.lifetimeUnlock } ?? products.first
    }

    // MARK: - Achat

    /// Déclenche l'achat d'un produit.
    /// - Returns: `true` si l'achat a abouti et que le contenu est débloqué.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Vérifie la signature de la transaction (anti-fraude).
                let transaction = try checkVerified(verification)
                // Met à jour l'état possédé puis clôt la transaction.
                await refreshPurchasedProducts()
                await transaction.finish()
                errorMessage = nil
                return true

            case .userCancelled:
                // L'utilisateur a fermé la feuille d'achat : pas une erreur.
                return false

            case .pending:
                // Ask to Buy / approbation parentale : la transaction
                // arrivera plus tard via `listenForTransactions()`.
                errorMessage = "Achat en attente d'approbation."
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "L'achat a échoué : \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restauration

    /// Restaure les achats (bouton "Restaurer les achats" du paywall).
    ///
    /// `AppStore.sync()` force une synchronisation avec l'App Store —
    /// utile si l'utilisateur a changé d'appareil ou réinstallé l'app.
    /// En temps normal, `Transaction.currentEntitlements` suffit déjà.
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
            errorMessage = isPremium ? nil : "Aucun achat à restaurer sur ce compte."
        } catch {
            errorMessage = "Restauration impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - Vérification de l'état

    /// Recalcule `purchasedProductIDs` et `isPremium` depuis
    /// `Transaction.currentEntitlements` (la source de vérité StoreKit 2 :
    /// ne contient QUE les achats valides — abonnements actifs et
    /// non-consommables non remboursés).
    ///
    /// Appelée au lancement (via PremiumManager), après chaque achat,
    /// et à chaque transaction reçue par le listener.
    func refreshPurchasedProducts() async {
        var owned: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            // Ignore les achats remboursés / révoqués par Apple.
            guard transaction.revocationDate == nil else { continue }
            owned.insert(transaction.productID)
        }

        purchasedProductIDs = owned
        isPremium = !owned.isDisjoint(with: PremiumProductID.all)
    }

    // MARK: - Listener de transactions

    /// Écoute en continu les transactions qui n'arrivent PAS par un achat
    /// direct dans l'app : renouvellement d'abonnement, remboursement,
    /// achat approuvé plus tard (Ask to Buy), achat sur un autre appareil.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.refreshPurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Transaction non vérifiable : on ne débloque rien.
                }
            }
        }
    }

    // MARK: - Vérification cryptographique

    /// Déballe un `VerificationResult` : StoreKit 2 vérifie automatiquement
    /// la signature (JWS) de chaque transaction. Une transaction
    /// `.unverified` ne doit JAMAIS débloquer de contenu.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
