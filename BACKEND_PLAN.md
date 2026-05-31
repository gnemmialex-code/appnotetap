# Plan d'architecture — « Mon espace » (fonctionnalités sur-mesure payantes)

Objectif : un utilisateur décrit une idée → tu la reçois dans un **dashboard admin** →
tu la développes → tu le **préviens** (push + e-mail) → il **paie** pour débloquer →
le contenu apparaît dans **son espace**. Tu veux aussi voir le **dashboard de chaque
utilisateur** et pouvoir le **contacter par e-mail**.

> ⚠️ Cela ne peut pas fonctionner dans l'app seule : il faut un **backend**.
> Recommandation : **Firebase** (le plus rapide pour ce besoin : auth + base + push +
> fonctions serveur + hébergement du dashboard). Alternative : Supabase (Postgres).

---

## 0. Règles Apple à connaître AVANT de coder

| Sujet | Règle | Conséquence concrète |
|---|---|---|
| **Paiement de contenu/fonction numérique** | Apple **impose l'In-App Purchase (IAP)**. Stripe/PayPal interdits pour ça. | Le « Débloquer » = un produit IAP. Commission 15–30 %. |
| **E-mail de l'utilisateur** | « Sign in with Apple » → option **« Masquer mon e-mail »** = adresse **relais** (pas la vraie). | Tu peux lui écrire via le relais **si** tu configures un domaine d'envoi vérifié. Pas d'accès libre à sa boîte. |
| **App soumise à la review** | L'app doit être **fonctionnelle** à la review ; le contenu peut être **piloté par serveur**. | OK pour livrer une fonctionnalité « après coup » via le serveur, mais pas une build différente par personne. |
| **Confidentialité** | Politique de confidentialité obligatoire + fiche « App Privacy ». | Prévois une page de politique + mention des données collectées. |

---

## 1. Configuration Apple Developer

1. **Sign in with Apple**
   - Active la capability *Sign in with Apple* sur l'App ID.
   - Crée une **Services ID** + **Key (.p8)** pour vérifier les tokens côté serveur.
2. **Hide My Email / e-mail relais**
   - Dans *Certificates, Identifiers & Profiles → More → Configure Sign in with Apple for Email Communication*.
   - Ajoute et **vérifie le domaine** d'envoi (SPF/DKIM) → tu pourras écrire à l'adresse relais `xxxx@privaterelay.appleid.com`.
3. **In-App Purchase**
   - Crée les produits dans **App Store Connect** (type *Non-Consumable* pour « déblocage à vie » d'une fonctionnalité).
   - Idée : un produit générique « unlock_feature » + le serveur associe le paiement à la bonne demande ; ou un produit par demande (plus lourd).
4. **Notifications push (APNs)**
   - Crée une **APNs Auth Key (.p8)** → à fournir à Firebase Cloud Messaging.

---

## 2. Backend Firebase

### Services activés
- **Authentication** : Sign in with Apple (+ e-mail si tu veux).
- **Cloud Firestore** : base de données temps réel.
- **Cloud Functions** : logique serveur (changement de statut, envoi push/e-mail, validation des reçus IAP).
- **Cloud Messaging (FCM)** : notifications push.
- **Storage** (optionnel) : pièces jointes / contenu livré.
- **Hosting** : pour héberger le **dashboard admin** (app web privée).

### Schéma Firestore
```
users/{uid}
  - displayName
  - appleRelayEmail        // adresse relais (si dispo)
  - fcmTokens: [ ... ]      // pour les push
  - createdAt
  - isAdmin: false          // toi = true

  requests/{requestId}      // sous-collection : les demandes de l'utilisateur
    - text                  // l'idée écrite
    - status                // sent | doing | ready | paid
    - price                 // ex. "4,99 €"
    - productId             // identifiant IAP associé
    - deliveredContent      // ce que tu livres (texte/config/lien)
    - createdAt, updatedAt
    - paidAt
```

### Règles de sécurité (principe)
- Un utilisateur lit/écrit **uniquement** `users/{son uid}` et ses `requests`.
- Le **statut**, le **prix** et `deliveredContent` ne sont modifiables **que par l'admin**
  (ou via Cloud Functions) — jamais par le client.
- L'admin (`isAdmin == true`) peut lire **tous** les users/requests → c'est ce qui te
  donne accès au « dashboard de chaque utilisateur ».

```
// firestore.rules (extrait)
match /users/{uid} {
  allow read, write: if request.auth.uid == uid || isAdmin();
  match /requests/{rid} {
    allow create: if request.auth.uid == uid;
    allow read:   if request.auth.uid == uid || isAdmin();
    // le client ne peut PAS changer status/price/deliveredContent
    allow update: if isAdmin();
  }
}
function isAdmin() {
  return request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}
```

---

## 3. Le flux complet, étape par étape

1. **Connexion** : l'utilisateur se connecte (Sign in with Apple) → création `users/{uid}`,
   on stocke l'e-mail relais + le token FCM.
2. **Envoi d'idée** : l'app crée `requests/{id}` avec `status: "sent"`.
3. **Toi (admin)** : ton dashboard liste toutes les demandes → tu passes en `doing`,
   tu développes, tu remplis `deliveredContent` + `price`, puis `status: "ready"`.
4. **Alerte** : une **Cloud Function** déclenchée au passage en `ready` envoie une
   **push (FCM)** + un **e-mail** (via le relais Apple ou un service type SendGrid/Resend).
5. **Paiement** : l'utilisateur appuie sur « Débloquer » → **IAP**. Le reçu est envoyé à
   une Cloud Function qui **valide auprès d'Apple**, puis passe `status: "paid"`.
6. **Accès** : l'app affiche `deliveredContent` car `status == "paid"` (vérifié côté règles).

---

## 4. Côté Flutter (paquets)

```yaml
dependencies:
  firebase_core: ^3.x
  firebase_auth: ^5.x
  sign_in_with_apple: ^6.x
  cloud_firestore: ^5.x
  firebase_messaging: ^15.x
  in_app_purchase: ^3.x        # ou: purchases_flutter (RevenueCat) pour simplifier l'IAP
```

> **RevenueCat** (purchases_flutter) simplifie énormément la validation des achats et le
> suivi des droits ; recommandé si tu ne veux pas écrire la validation des reçus toi-même.

---

## 5. Dashboard admin (pour TOI)

Deux options :
- **Le plus simple** : une petite **app web** (Flutter Web ou React) déployée sur
  **Firebase Hosting**, connectée avec ton compte admin (`isAdmin: true`). Elle liste
  tous les `users` et leurs `requests`, permet de changer le statut, écrire le contenu
  livré, fixer le prix, et contacter par e-mail.
- **Très rapide pour démarrer** : utiliser directement la **console Firebase**
  (onglet Firestore) pour éditer les documents à la main, le temps d'avoir peu d'users.

C'est le flag `isAdmin` + les règles de sécurité qui te donnent l'accès à **tous** les
espaces utilisateurs.

---

## 6. E-mail : ce qui est possible

- Tu obtiens **au mieux** l'adresse **relais** Apple (si l'utilisateur masque son e-mail).
- Pour lui écrire : configure le **domaine d'envoi** dans Apple Developer (étape 1.2),
  puis envoie via une Cloud Function (SendGrid / Resend / Mailgun) **vers cette adresse**.
- Tu **ne peux pas** parcourir/lire la boîte mail de l'utilisateur — seulement lui écrire.

---

## 7. Ordre de mise en œuvre conseillé

1. Projet Firebase + `flutterfire configure`.
2. Sign in with Apple (auth + création du profil user).
3. Firestore + règles de sécurité + envoi d'idée (remplace le « simulé » actuel).
4. Dashboard admin minimal (ou console Firebase au début).
5. Cloud Function « ready » → push + e-mail.
6. In-App Purchase (ou RevenueCat) + validation → `paid`.
7. Affichage du contenu débloqué.

---

### Estimation
- MVP (auth + idées + dashboard console + statut manuel) : faisable rapidement.
- Version complète (push + e-mail + IAP validé serveur) : plus conséquent, surtout l'IAP.

> Le prototype web actuel (`TapBackCommand/web-prototype`) simule ce flux côté interface
> pour valider l'UX **avant** de brancher le backend.
