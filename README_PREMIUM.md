# TapBack Command — Premium (StoreKit 2) & fenêtre flottante

Guide interne. L'app garde son nom et son bundle ID existants
(`com.gnemmialex.tapbacknote`) — rien à changer de ce côté.

---

## 1. Créer les produits In-App dans App Store Connect

1. Connectez-vous sur https://appstoreconnect.apple.com avec votre compte.
2. Ouvrez votre app existante (NE PAS en créer une nouvelle — le bundle ID
   `com.gnemmialex.tapbacknote` est déjà associé).
3. Dans le menu latéral : **Monétisation → Achats intégrés** (In-App Purchases).
4. Créez les produits :

   a) Achat unique "à vie" :
      - Type : **Non consommable** (Non-Consumable)
      - ID produit : `com.gnemmialex.tapbacknote.premium.lifetime`
        (ou le vôtre — voir section 2)
      - Prix, nom affiché ("Premium à vie"), description, capture d'écran
        de revue.

   b) Abonnement mensuel :
      - Menu : **Monétisation → Abonnements** (Subscriptions)
      - Créez un **groupe d'abonnements** (ex. "TapBack Premium"), puis
        un abonnement dedans :
      - ID produit : `com.gnemmialex.tapbacknote.premium.monthly`
      - Durée : 1 mois, prix, nom, description.

5. Remplissez les métadonnées obligatoires (sinon les produits ne seront
   jamais retournés par `Product.products(for:)`, même en sandbox) :
   nom affiché, description, prix, et au moins une capture pour la revue.
6. Vérifiez que l'**Accord d'applications payantes** (Paid Apps Agreement)
   est signé dans App Store Connect → Accords, taxes et opérations bancaires.
   Sans cela, les produits ne se chargent pas.
7. Dans Xcode : cible de l'app → Signing & Capabilities → ajoutez la
   capability **In-App Purchase** si elle n'y est pas déjà.

---

## 2. Renseigner les identifiers dans StoreManager

Fichier : `TapBackCommand/Services/StoreManager.swift`, enum `PremiumProductID`
(tout en haut du fichier). C'est le SEUL endroit à modifier :

    enum PremiumProductID {
        static let monthlySubscription = "com.gnemmialex.tapbacknote.premium.monthly"
        static let lifetimeUnlock      = "com.gnemmialex.tapbacknote.premium.lifetime"
        static let all: Set<String> = [monthlySubscription, lifetimeUnlock]
    }

- Remplacez les chaînes par vos ID produits exacts d'App Store Connect.
- Vous pouvez ajouter / retirer des produits dans `all` : le paywall et la
  vérification premium s'adaptent automatiquement.
- Le produit mis en avant dans le paywall est l'achat à vie s'il existe,
  sinon le premier produit (propriété `featuredProduct`).

---

## 3. Tester les achats en sandbox

Option A — StoreKit Configuration (sans réseau, recommandé en dev) :
1. Xcode : File → New → File… → **StoreKit Configuration File**.
2. Ajoutez-y des produits avec les MÊMES ID que `PremiumProductID`.
3. Schéma de l'app : Edit Scheme → Run → Options →
   **StoreKit Configuration** → sélectionnez votre fichier.
4. Lancez : les achats sont simulés localement. Le menu
   Debug → StoreKit → Manage Transactions permet de rembourser /
   expirer / supprimer des transactions pour tester tous les cas.

Option B — Sandbox App Store (vrai serveur Apple) :
1. App Store Connect → **Utilisateurs et accès → Sandbox → Testeurs** :
   créez un compte testeur sandbox (e-mail jamais utilisé comme Apple ID).
2. Sur l'iPhone : Réglages → App Store → tout en bas, section
   **Compte sandbox** → connectez le testeur.
3. Installez l'app via Xcode ou TestFlight et achetez : aucun débit réel.
4. Les abonnements sandbox sont accélérés (1 mois ≈ 5 minutes) pour
   tester les renouvellements et expirations.

---

## 4. Vérifier l'état premium

API simple, depuis n'importe où :

    if PremiumManager.shared.isPremium { ... }

Dans une vue SwiftUI (réactif) :

    @ObservedObject private var premium = PremiumManager.shared
    // ou via l'environment (injecté dans TapBackCommandApp) :
    @EnvironmentObject private var premium: PremiumManager

    var body: some View {
        if premium.isPremium {
            FonctionnaliteAvancee()
        } else {
            PremiumPaywallView()   // ou .sheet(isPresented:)
        }
    }

Cycle de vie de l'état :
- Au cold start : `PremiumManager` lit un cache UserDefaults → valeur
  instantanée, pas de flash de paywall.
- Puis `refreshAtLaunch()` (appelé par `.task` dans TapBackCommandApp)
  interroge `Transaction.currentEntitlements` (StoreKit 2) : c'est la
  source de vérité. Abonnement expiré ou achat remboursé → `isPremium`
  repasse à false automatiquement.
- Le listener `Transaction.updates` (dans StoreManager) capte en continu
  les renouvellements, remboursements et achats faits ailleurs.
- Restauration manuelle : `await PremiumManager.shared.restorePurchases()`
  (branché sur le bouton "Restaurer les achats" du paywall).

---

## 5. Fenêtre flottante : déclenchement & lien avec Premium

Déclenchement (depuis n'importe où — App Intent, onOpenURL, bouton…) :

    QuickNoteManager.shared.presentFloatingWindow()

    // ou, découplé (recommandé depuis un widget / une extension) :
    NotificationCenter.default.post(name: .openQuickNote, object: nil)

    // Fermeture :
    QuickNoteManager.shared.dismissFloatingWindow()

Sources déjà branchées :
- `OpenQuickNoteIntent` (Back Tap / Siri / Raccourcis)
- URL scheme `tapbackcommand://openQuickNote` (géré dans TapBackCommandApp)

Affichage :
- `RootView` observe `QuickNoteManager.shared.isPresented` et affiche
  `FloatingQuickNoteView` en overlay (zIndex 20) quand c'est true.
- Le panneau blanc est collé au bord physique de l'écran : son fond
  remonte sous l'encoche (`.ignoresSafeArea(edges: .top)` sur la forme
  de fond), seuls les coins inférieurs sont arrondis, et il glisse
  depuis le haut avec une animation spring. Le reste de l'écran est
  grisé. Swipe vers le haut ou tap à l'extérieur = fermeture.

Lien avec Premium (dans FloatingQuickNoteView) :
- PREMIUM     → fenêtre complète : note texte + actions rapides
  (Vocal / To-Do / Capture) actives.
- NON PREMIUM → version limitée : la note texte simple reste utilisable ;
  les actions rapides sont verrouillées (icône cadenas) et un bandeau
  "Version gratuite" est affiché. Toucher une action verrouillée ou le
  bandeau ouvre `PremiumPaywallView` en sheet.
- Après un achat réussi, le paywall se ferme tout seul
  (`.onChange(of: premium.isPremium)`) et les actions se déverrouillent
  immédiatement (la vue observe `PremiumManager.shared`).

Fichiers concernés :
- `TapBackCommand/Services/StoreManager.swift`    — StoreKit 2 pur
- `TapBackCommand/Services/PremiumManager.swift`  — état métier + cache
- `TapBackCommand/Views/PremiumPaywallView.swift` — paywall
- `TapBackCommand/Views/FloatingQuickNoteView.swift` — fenêtre encoche
- `TapBackCommand/Services/QuickNoteManager.swift` — présentation
- `TapBackCommand/TapBackCommandApp.swift`        — init + revalidation
