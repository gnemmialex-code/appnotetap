# README_BACKTAP.md — TapBack Command : Back Tap & Raccourcis

## Pourquoi App Intents est recommandé

**App Intents** (iOS 16+) s'intègre nativement à l'app Raccourcis et à la
fonctionnalité Back Tap. L'intent `OpenQuickNoteIntent` apparaît
automatiquement dans l'app Raccourcis sans aucune configuration serveur.
L'utilisateur peut l'associer à Back Tap en deux touches dans les Réglages.

**L'URL scheme** (`tapbackcommand://openQuickNote`) est un fallback utile
pour les appareils sous iOS 15 ou pour les raccourcis créés avec l'action
"Ouvrir URL" dans l'app Raccourcis. Il couvre aussi les deep links depuis
une autre app ou un script de test.

---

## Architecture des fichiers créés

```
TapBackCommand/
├── Intents/
│   └── OpenQuickNoteIntent.swift      ← AppIntent iOS 16+
├── Services/
│   └── QuickNoteManager.swift         ← Singleton + Notification.Name
├── Views/
│   └── SettingsGuideView.swift        ← Vue d'aide (French)
├── QuickNoteHooks.swift               ← Exemples de hooks publics (optionnel)
├── TapBackCommandApp.swift            ← Modifié : onOpenURL + QuickNoteManager
└── SupportingFiles/
    └── Info.plist                     ← Modifié : URL scheme + NSUserActivityTypes
README_BACKTAP.md                      ← Ce fichier
```

---

## Où placer les fichiers dans Xcode

1. **Intents/OpenQuickNoteIntent.swift** → glissez dans le groupe `TapBackCommand`
   (créez un groupe `Intents` si souhaité). Assurez-vous que la target membership
   est cochée pour `TapBackCommand`.
2. **Services/QuickNoteManager.swift** → glissez dans le groupe `Services`.
3. **Views/SettingsGuideView.swift** → glissez dans le groupe `Views`.
4. **QuickNoteHooks.swift** → à la racine du groupe `TapBackCommand` (optionnel).
5. **SupportingFiles/Info.plist** → déjà dans le projet ; les clés ont été ajoutées.
6. **TapBackCommandApp.swift** → déjà dans le projet ; les additions sont clairement
   marquées par des commentaires `── Ajouts Back Tap / URL scheme ──`.

---

## Capabilities Xcode à activer

- **Siri** (Signing & Capabilities) : demandé par Xcode pour certaines versions ;
  cochez-la sur la cible principale si Xcode le demande.
- Aucun autre entitlement spécial n'est requis pour les URL schemes.
- **Background Modes** n'est pas nécessaire pour ce scheme.

> ⚠️  L'entitlement `com.apple.developer.siri` peut être nécessaire selon
> votre profil de provisionnement. Activez la capability Siri dans Xcode →
> Signing & Capabilities si le build échoue avec une erreur d'entitlement.

---

## URLs valides et invalides

| URL | Résultat |
|-----|----------|
| `tapbackcommand://openQuickNote` | ✅ Ouvre la fenêtre flottante |
| `tapbackcommand://openquicknote` | ✅ Idem (insensible à la casse) |
| `tapbackcommand://other` | ❌ Ignorée silencieusement |
| `tapbackcommand://openQuickNote/extra` | ❌ Ignorée silencieusement |
| `https://example.com` | ❌ Ignorée silencieusement |
| `tapbackcommand://` | ❌ Ignorée silencieusement |

---

## Texte d'aide exact (prêt à coller dans SettingsGuideView)

```
Configurer Toucher le dos

1. Ouvrez Réglages → Accessibilité → Toucher → Toucher le dos.
2. Choisissez Double‑tap (ou Triple‑tap).
3. Sélectionnez Raccourci puis choisissez le raccourci nommé
   « Ouvrir la petite fenêtre » fourni par l'application.
4. Revenez dans l'app et testez en tapant deux fois l'arrière
   de votre iPhone.

Bouton : Aller aux Réglages
```

---

## Étapes de configuration Back Tap (utilisateur final)

### Méthode A — App Intent (iOS 16+, recommandée)

1. Ouvrez l'app **Raccourcis** sur l'iPhone.
2. Appuyez sur **+** (nouveau raccourci).
3. Recherchez **« Ouvrir la petite fenêtre de note »** → ajoutez l'action.
4. Nommez le raccourci **« Ouvrir la petite fenêtre »**.
5. Sauvegardez.
6. Ouvrez **Réglages → Accessibilité → Toucher → Toucher le dos**.
7. Choisissez **Double‑tap** (ou Triple‑tap).
8. Sélectionnez **Raccourci** → choisissez **« Ouvrir la petite fenêtre »**.
9. Revenez dans TapBack Command et tapez deux fois l'arrière de l'iPhone.

> ⚠️  iOS n'autorise aucune app tierce à ouvrir ou configurer directement
> le panneau Toucher le dos. Cette étape est **toujours manuelle**.

### Méthode B — URL scheme (iOS 15 ou fallback)

1. Ouvrez l'app **Raccourcis** → **+** → recherchez **« Ouvrir URL »**.
2. Entrez l'URL : `tapbackcommand://openQuickNote`
3. Nommez le raccourci **« Ouvrir la petite fenêtre »**.
4. Suivez les étapes 6-9 de la Méthode A.

---

## Checklist de tests manuels

### Tests fonctionnels

- [ ] **App Intent manuel** : Raccourcis → exécuter « Ouvrir la petite fenêtre
  de note » → la fenêtre flottante s'affiche.
- [ ] **URL scheme** : Raccourcis → exécuter le raccourci « Ouvrir URL »
  `tapbackcommand://openQuickNote` → la fenêtre s'affiche.
- [ ] **Back Tap Double-tap** : configurer le raccourci (Méthode A ou B),
  taper deux fois l'arrière → la fenêtre s'affiche.
- [ ] **Cold start via App Intent** : fermer l'app complètement → exécuter
  le raccourci → l'app s'ouvre ET la fenêtre flottante s'affiche.
- [ ] **Cold start via URL** : fermer l'app → raccourci "Ouvrir URL" → idem.
- [ ] **URL malformée** : `tapbackcommand://other` → ignorée, pas de crash.
- [ ] **URL scheme inconnu** : `https://example.com` → ignorée, pas de crash.
- [ ] **Intent visible dans Raccourcis** : ouvrir Raccourcis → Galerie →
  TapBack Command → « Ouvrir la petite fenêtre de note » présent.
- [ ] **isPresented** : vérifier que `QuickNoteManager.shared.isPresented`
  passe à `true` après déclenchement et repasse à `false` après fermeture.

### Tests unitaires recommandés

```swift
// Vérifier que isPresented passe à true lors de la notification
func testNotificationSetsIsPresented() async {
    let manager = QuickNoteManager.shared
    NotificationCenter.default.post(name: .openQuickNote, object: nil)
    // Attendre le RunLoop
    await Task.yield()
    XCTAssertTrue(manager.isPresented)
}

// Vérifier que handleIncomingURL ignore les schemes non reconnus
func testHandleIncomingURLIgnoresUnknownScheme() {
    // Si handleIncomingURL est private, testez via .onOpenURL simulé
    // ou extrayez la logique dans une fonction interne testable.
    let url = URL(string: "https://example.com")!
    // Appel → QuickNoteManager.shared.isPresented doit rester false
}
```

---

## Checklist App Store Connect / TestFlight

- [ ] Aucune configuration spéciale App Store Connect n'est requise pour Back Tap.
- [ ] Back Tap est une fonctionnalité **iOS uniquement** (iPhone ; non disponible
  sur iPad ni simulateur).
- [ ] Dans les **notes de testeur TestFlight**, ajoutez :

```
Pour tester Back Tap :
1. Raccourcis → + → "Ouvrir la petite fenêtre de note" → sauvegarder.
2. Réglages → Accessibilité → Toucher → Toucher le dos → Double‑tap
   → Raccourci → choisir le raccourci créé.
3. Taper deux fois l'arrière de l'iPhone → la mini-fenêtre s'affiche.
```

- [ ] La fonctionnalité Back Tap **n'est pas disponible sur simulateur**.
  Testez uniquement sur un iPhone physique (iPhone 8 ou ultérieur).
- [ ] Vérifiez que le scheme `tapbackcommand` n'est pas déjà utilisé par une
  autre app installée sur le device de test.

---

## Script de vérification (CLI)

```bash
# Vérifier que OpenQuickNoteIntent est présent dans les sources
rg "OpenQuickNoteIntent" --type swift

# Vérifier que le scheme tapbackcommand est déclaré dans Info.plist
rg "tapbackcommand" TapBackCommand/SupportingFiles/Info.plist

# Vérifier que Notification.Name.openQuickNote est définie
rg "openQuickNote" --type swift

# Vérifier que QuickNoteManager.shared est initialisé dans l'App
rg "QuickNoteManager.shared" TapBackCommand/TapBackCommandApp.swift
```

---

## Note sur NSUserActivityTypes

`NSUserActivityTypes` dans Info.plist est utile (mais non obligatoire) pour que
le système pré-indexe les App Intents même après un cold start. Ajoutez
`OpenQuickNoteIntent` à ce tableau (déjà fait dans Info.plist) pour garantir la
disponibilité dans Siri et Raccourcis sans lancement préalable de l'app.
