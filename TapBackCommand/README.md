# TapBack Command

App iOS minimaliste : 3 actions instantanées (🎙️ note vocale, ✏️ to-do, ⭐ capture intelligente) accessibles via une **mini-fenêtre flottante** déclenchée par le **Tap-Back** (Toucher le dos de l'iPhone).

SwiftUI · MVVM · Combine/async-await · AVFoundation · Speech · Vision · AppIntents · UserNotifications · EventKit.

---

## ⚠️ Réalité technique du « Tap-Back » sur iOS (à lire)

Contrairement à Android, **iOS n'autorise aucune app tierce à dessiner une fenêtre par-dessus les autres apps**. Le Back Tap (Réglages → Accessibilité → Toucher → Toucher le dos) ne peut lancer **qu'un Raccourci**, qui exécute un **App Intent**.

Conséquence : la mini-fenêtre flottante s'affiche **à l'intérieur de TapBack Command** lorsque le Tap-Back amène l'app au premier plan. C'est le maximum permis par le système et c'est 100 % conforme à l'App Store. Tout est codé ainsi (voir `BackTapService.swift`).

De même, lire le contenu d'une autre app (URL Safari, sélection Messages…) est interdit par le bac à sable. La capture utilise donc le **presse-papiers** + le **Partage → TapBack** (Share Extension) + **PHPicker** pour les photos (voir `ContextDetectionService.swift`).

---

## Mise en place dans Xcode

Ces fichiers sont prêts à l'emploi mais doivent vivre dans un projet Xcode :

1. Xcode → **New Project** → iOS **App** → SwiftUI → nom `TapBackCommand`, **iOS 17+**.
2. Supprime le `ContentView.swift` généré, puis glisse le dossier `TapBackCommand/` (Models, ViewModels, Views, Services, Utils) dans le projet (*Create groups*).
3. Fusionne les clés de `SupportingFiles/Info.plist` dans l'onglet **Info** de la cible (micro, speech, rappels, photos).
4. **Signing & Capabilities** → ajoute *Background Modes → Audio* si tu veux finir un enregistrement en arrière-plan.
5. Build & Run sur un **appareil réel** (le micro et le Tap-Back ne marchent pas au simulateur).

### Activer le Tap-Back
App → onglet Notes → bouton **?** → instructions pas à pas (écran `BackTapOnboardingView`).
Résumé : crée un Raccourci « Ouvrir TapBack Command », puis Réglages → Accessibilité → Toucher → Toucher le dos → Double Tap → choisis ce raccourci.

---

## Architecture

```
TapBackCommandApp.swift      App entry + AppRouter (état global / overlay)
Models/                      Note · Todo · Capture (Codable)
ViewModels/                  Recorder · Notes · Todo · Capture (@MainActor)
Views/
  RootView                   TabView + overlay flottant + routage des sheets
  FloatingCommandView        La capsule « Dynamic Island élargie » (3 boutons)
  VoiceRecorderView          Bouton record, waveform animée, timer, résultats
  TodoQuickAddView           Champ minimal + rappel iOS optionnel
  CaptureView                Contexte/photo/URL → Capture
  *ListView / *DetailView    Listes Notes / To-Do / Captures
  BackTapOnboardingView      Guide d'activation Tap-Back
Services/
  AudioRecorderService       AVAudioRecorder + metering live (waveform)
  TranscriptionService       Speech, on-device (fr-FR)
  SummarizerService          Résumé + plan : moteur local (offline) inclus,
                             + RemoteSummarizer (placeholder API LLM)
  ContextDetectionService    Presse-papiers / partage / Vision (tags photo)
  ReminderService            UserNotifications + EventKit
  StorageService             Persistance JSON (Documents) + assets
  BackTapService             App Intents + AppShortcutsProvider
Utils/                       Constants (design tokens) · Haptics · Extensions
```

## Notes d'implémentation

- **Résumé/plan** : `LocalHeuristicSummarizer` fonctionne hors-ligne (extraction de phrases salientes via `NaturalLanguage`, lemmatisation + stop-words FR). Dire « **fais un plan** » dans la note déclenche un plan structuré automatiquement ; sinon bouton « Générer un plan ». Pour brancher un vrai LLM, implémente `RemoteSummarizer` et fais `SummarizerService.shared.engine = RemoteSummarizer()`.
- **Transcription** : `requiresOnDeviceRecognition` activé quand dispo → privé et offline.
- **Stockage** : JSON simple et inspectable ; l'API `StorageService` est volontairement minimale pour migrer vers SwiftData/CoreData sans toucher aux ViewModels.
- **Design** : noir / blanc / gris translucide, `.ultraThinMaterial`, SF Symbols, haptics, animations spring. Tous les écrans ont un `#Preview`.
```
