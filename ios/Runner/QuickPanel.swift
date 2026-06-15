// QuickPanel.swift — Panneau rapide Shortist rendu PAR LE SYSTÈME.
//
// iOS 26 : App Intents + snippets interactifs → le panneau s'affiche en carte
// flottante par-dessus l'app en cours (via Raccourcis / Toucher le dos),
// sans JAMAIS ouvrir l'application (openAppWhenRun = false).
// iOS 16–25 : fallback « Note rapide » / « Tâche rapide » via la boîte de
// dialogue système (saisie de texte), toujours sans ouvrir l'app.
//
// ⚠️ Compilation : exige le SDK iOS 26 (Xcode 26). Le deployment target du
// projet reste 13.0, tout est annoté @available.
//
// Stockage : shared_preferences (Flutter) écrit dans UserDefaults.standard
// avec le préfixe "flutter." → on lit/écrit ici le MÊME JSON que lib/store.dart
// (clés tbc_notes / tbc_todos / tbc_reading). Pas d'App Group nécessaire :
// les intents de la cible principale s'exécutent dans le conteneur de l'app.
// Côté Flutter, Store.load() fait un prefs.reload() au retour au premier plan
// pour ne pas écraser ce que les intents ont écrit en arrière-plan.

import AppIntents
import SwiftUI

// MARK: - Pont de stockage vers shared_preferences (lib/store.dart)

enum ShortistNativeStore {

  private static let appGroup  = "group.com.gnemmialex.tapbacknote"
  private static let notesKey   = "flutter.tbc_notes"
  private static let todosKey   = "flutter.tbc_todos"
  private static let readingKey = "flutter.tbc_reading"

  /// Même format d'identifiant que `_uid()` côté Dart
  /// (microsecondes epoch en base 36).
  static func newId() -> String {
    String(Int(Date().timeIntervalSince1970 * 1_000_000), radix: 36)
  }

  // Dart `DateTime.toIso8601String()` : heure locale, sans fuseau,
  // fraction de seconde de 0 à 6 chiffres. On écrit en millisecondes
  // (Dart le re-parse sans problème) et on lit de façon tolérante.
  private static func formatter(_ format: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = format
    return f
  }

  private static let writeFormatter = formatter("yyyy-MM-dd'T'HH:mm:ss.SSS")
  private static let readFormatters = [
    formatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
    formatter("yyyy-MM-dd'T'HH:mm:ss.SSS"),
    formatter("yyyy-MM-dd'T'HH:mm:ss"),
  ]

  static func dartDateString(_ date: Date) -> String {
    writeFormatter.string(from: date)
  }

  static func parseDartDate(_ raw: Any?) -> Date? {
    guard let s = raw as? String, !s.isEmpty else { return nil }
    for f in readFormatters {
      if let d = f.date(from: s) { return d }
    }
    // Au cas où une date UTC ("...Z") se serait glissée dans le JSON.
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
  }

  /// Lit une liste JSON telle quelle ([[String: Any]]) pour préserver
  /// tous les champs Dart, y compris ceux inconnus côté Swift.
  private static func loadList(_ key: String) -> [[String: Any]] {
    guard
      let raw = UserDefaults.standard.string(forKey: key),
      let data = raw.data(using: .utf8),
      let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return list
  }

  private static func saveList(_ key: String, _ list: [[String: Any]]) {
    guard
      let data = try? JSONSerialization.data(withJSONObject: list),
      let raw = String(data: data, encoding: .utf8)
    else { return }
    UserDefaults.standard.set(raw, forKey: key)
    // Miroir dans l'App Group pour que le Widget Home Screen voie les
    // modifications en temps réel (même sans ouvrir l'app).
    UserDefaults(suiteName: appGroup)?.set(raw, forKey: key)
  }

  // --- Écritures (mêmes formes JSON que models.dart) ---

  static func addNote(title: String, body: String) {
    var notes = loadList(notesKey)
    notes.insert([
      "id": newId(),
      "createdAt": dartDateString(Date()),
      "title": title.isEmpty ? "Note" : title,
      "body": body,
      "plan": [String](),
    ], at: 0)
    saveList(notesKey, notes)
  }

  static func addTodo(text: String, description: String = "") {
    var todos = loadList(todosKey)
    todos.insert([
      "id": newId(),
      "createdAt": dartDateString(Date()),
      "text": text,
      "description": description,
      "done": false,
      "doneAt": NSNull(),
    ], at: 0)
    saveList(todosKey, todos)
  }

  static func addReading(text: String, imageB64: String? = nil) {
    var reading = loadList(readingKey)
    var item: [String: Any] = [
      "id": newId(),
      "createdAt": dartDateString(Date()),
      "text": text,
      "remindAt": NSNull(),
      "done": false,
    ]
    if let b64 = imageB64, !b64.isEmpty { item["imageB64"] = b64 }
    reading.insert(item, at: 0)
    saveList(readingKey, reading)
  }

  static func toggleTodo(id: String) {
    var todos = loadList(todosKey)
    guard let i = todos.firstIndex(where: { $0["id"] as? String == id }) else { return }
    let nowDone = !(todos[i]["done"] as? Bool ?? false)
    todos[i]["done"] = nowDone
    todos[i]["doneAt"] = nowDone ? dartDateString(Date()) : NSNull()
    saveList(todosKey, todos)
  }

  // --- Lecture pour le panneau ---

  struct PanelTodo: Identifiable {
    let id: String
    let text: String
    let done: Bool
  }

  /// Mêmes règles que `Store.quickPanelTodos` (Dart) : tâches non faites,
  /// ou faites depuis moins de 10 min ; les 5 premières.
  static func quickPanelTodos() -> [PanelTodo] {
    loadList(todosKey)
      .filter { dict in
        let done = dict["done"] as? Bool ?? false
        if !done { return true }
        guard let doneAt = parseDartDate(dict["doneAt"]) else { return false }
        return Date().timeIntervalSince(doneAt) < 10 * 60
      }
      .prefix(5)
      .map {
        PanelTodo(
          id: $0["id"] as? String ?? "",
          text: $0["text"] as? String ?? "",
          done: $0["done"] as? Bool ?? false
        )
      }
  }
}

// MARK: - Snippet interactif (iOS 26) : la carte flottante système

@available(iOS 26.0, *)
struct OpenPanelIntent: AppIntent {
  static let title: LocalizedStringResource = "Ouvrir le panneau"
  static let description = IntentDescription(
    "Affiche le panneau rapide Shortist par-dessus l'app en cours, sans ouvrir l'application."
  )
  // CRUCIAL : ne jamais ouvrir l'app — la carte est rendue par le système.
  static let openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ShowsSnippetIntent {
    .result(snippetIntent: PanelSnippetIntent())
  }
}

@available(iOS 26.0, *)
struct PanelSnippetIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Panneau Shortist"

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    // Ce perform() se ré-exécute après chaque tap de bouton : on recharge
    // l'état ici (jamais dans la vue) pour rafraîchir la carte.
    let todos = ShortistNativeStore.quickPanelTodos()
    return .result(view: PanelView(todos: todos))
  }
}

@available(iOS 26.0, *)
struct PanelView: View {
  let todos: [ShortistNativeStore.PanelTodo]

  var body: some View {
    VStack(spacing: 12) {
      Text("Shortist")
        .font(.system(size: 15, weight: .heavy))

      // Mêmes trois actions que le panneau Flutter (CommandPanel._choices).
      HStack(spacing: 8) {
        actionTile(intent: AddPanelNoteIntent(), icon: "square.and.pencil", label: "Note")
        actionTile(intent: AddPanelTodoIntent(), icon: "checklist", label: "To-Do")
        actionTile(intent: ShowReadingFormIntent(), icon: "bookmark", label: "À lire")
      }

      Text("⚡ Note supprimée après 24h · À lire pour conserver")
        .font(.system(size: 9.5))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      // « Dernières tâches » : coche directe, règle des 10 min côté store.
      if !todos.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Dernières tâches")
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
          ForEach(todos) { todo in
            Button(intent: TogglePanelTodoIntent(todoID: todo.id)) {
              HStack(spacing: 8) {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(todo.done ? .green : .secondary)
                Text(todo.text)
                  .font(.system(size: 13, weight: .medium))
                  .strikethrough(todo.done)
                  .foregroundStyle(todo.done ? .secondary : .primary)
                  .lineLimit(1)
                Spacer(minLength: 0)
              }
            }
            .buttonStyle(.plain)
          }
        }
      }

      Button(intent: OpenShortistAppIntent()) {
        HStack(spacing: 8) {
          Text("Ouvrir l'application")
            .font(.system(size: 14, weight: .bold))
          Image(systemName: "arrow.right")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.black)
    }
    .padding()
    // Le système fournit le fond « verre » de la carte flottante :
    // aucun fond ajouté ici pour garder l'effet Glass pur.
  }

  private func actionTile(intent: some AppIntent, icon: String, label: String) -> some View {
    Button(intent: intent) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 20))
        Text(label)
          .font(.system(size: 12, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      // Matériau translucide (pas de gris opaque) : les tuiles gardent
      // leur forme tout en laissant l'effet verre du panneau visible.
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Actions des boutons du snippet (arrière-plan, jamais d'ouverture d'app)

@available(iOS 26.0, *)
struct AddPanelNoteIntent: AppIntent {
  static let title: LocalizedStringResource = "Ajouter une note"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Note", requestValueDialog: "Quoi noter ? (supprimé après 24h)")
  var text: String

  func perform() async throws -> some IntentResult {
    ShortistNativeStore.addNote(title: "Note", body: text)
    return .result()
  }
}

@available(iOS 26.0, *)
struct AddPanelTodoIntent: AppIntent {
  static let title: LocalizedStringResource = "Ajouter une tâche"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Tâche", requestValueDialog: "Nouvelle tâche ?")
  var text: String

  func perform() async throws -> some IntentResult {
    ShortistNativeStore.addTodo(text: text)
    return .result()
  }
}

@available(iOS 26.0, *)
struct AddPanelReadingIntent: AppIntent {
  static let title: LocalizedStringResource = "À lire plus tard"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Lien ou texte", requestValueDialog: "Quoi lire plus tard ?")
  var text: String

  func perform() async throws -> some IntentResult {
    ShortistNativeStore.addReading(text: text)
    return .result()
  }
}

// MARK: - Formulaire « À lire » inline (iOS 26)

@available(iOS 26.0, *)
struct ShowReadingFormIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Formulaire À lire"

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    // Efface le brouillon précédent avant d'afficher le formulaire.
    UserDefaults.standard.removeObject(forKey: "qp_reading_draft")
    UserDefaults.standard.removeObject(forKey: "qp_reading_image_data")
    return .result(view: ReadingFormView())
  }
}

@available(iOS 26.0, *)
struct SaveReadingFromFormIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Enregistrer À lire"

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    let text = UserDefaults.standard.string(forKey: "qp_reading_draft") ?? ""
    let raw = UserDefaults.standard.data(forKey: "qp_reading_image_data") ?? Data()
    let imageB64: String? = raw.isEmpty ? nil : raw.base64EncodedString()
    ShortistNativeStore.addReading(text: text, imageB64: imageB64)
    UserDefaults.standard.removeObject(forKey: "qp_reading_draft")
    UserDefaults.standard.removeObject(forKey: "qp_reading_image_data")
    let todos = ShortistNativeStore.quickPanelTodos()
    return .result(view: PanelView(todos: todos))
  }
}

@available(iOS 26.0, *)
struct CancelReadingFormIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Annuler"

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    UserDefaults.standard.removeObject(forKey: "qp_reading_draft")
    UserDefaults.standard.removeObject(forKey: "qp_reading_image_data")
    let todos = ShortistNativeStore.quickPanelTodos()
    return .result(view: PanelView(todos: todos))
  }
}

// Saisie de texte via le dialog système (@Parameter) — TextField ne fonctionne
// pas dans les SnippetViews iOS 26.
@available(iOS 26.0, *)
struct EnterReadingTextIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Saisir le texte"

  @Parameter(title: "Texte ou lien", requestValueDialog: "Quoi lire plus tard ?")
  var text: String

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    UserDefaults.standard.set(text, forKey: "qp_reading_draft")
    return .result(view: ReadingFormView())
  }
}

// Sélection d'image via le file picker système (@Parameter IntentFile).
@available(iOS 26.0, *)
struct AddReadingImageIntent: SnippetIntent {
  static let title: LocalizedStringResource = "Choisir une image"

  @Parameter(title: "Image")
  var imageFile: IntentFile

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    if let raw = try? imageFile.data, !raw.isEmpty {
      UserDefaults.standard.set(Self.compress(raw), forKey: "qp_reading_image_data")
    }
    return .result(view: ReadingFormView())
  }

  private static func compress(_ raw: Data) -> Data {
    guard let ui = UIImage(data: raw) else { return raw }
    let scale = min(800 / ui.size.width, 800 / ui.size.height, 1)
    let size = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: size)
    let resized = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
    return resized.jpegData(compressionQuality: 0.75) ?? raw
  }
}

@available(iOS 26.0, *)
struct ReadingFormView: View {
  @AppStorage("qp_reading_draft") private var text = ""
  @AppStorage("qp_reading_image_data") private var imageData: Data = Data()

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("À lire plus tard")
        .font(.system(size: 15, weight: .heavy))
        .frame(maxWidth: .infinity, alignment: .center)

      // Bouton texte → dialog @Parameter
      Button(intent: EnterReadingTextIntent()) {
        HStack(spacing: 8) {
          Image(systemName: "text.cursor")
            .foregroundColor(.secondary)
          Text(text.isEmpty ? "Lien ou texte à retenir…" : text)
            .font(.system(size: 13))
            .foregroundColor(text.isEmpty ? .secondary : .primary)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
      }
      .buttonStyle(.plain)

      // Bouton image → file picker @Parameter
      Button(intent: AddReadingImageIntent()) {
        HStack(spacing: 6) {
          Image(systemName: imageData.isEmpty ? "photo.badge.plus" : "photo.fill")
            .foregroundColor(imageData.isEmpty ? .secondary : Color.blue)
          Text(imageData.isEmpty ? "Ajouter une image" : "Image sélectionnée ✓")
            .font(.system(size: 13))
            .foregroundColor(imageData.isEmpty ? .secondary : Color.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)

      // Aperçu image
      if !imageData.isEmpty, let ui = UIImage(data: imageData) {
        Image(uiImage: ui)
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: 80)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .clipped()
      }

      // Boutons de même taille — style custom identique pour les deux
      HStack(spacing: 8) {
        Button(intent: CancelReadingFormIntent()) {
          Text("Annuler")
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        Button(intent: SaveReadingFromFormIntent()) {
          Text("Enregistrer")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty
              ? Color.white.opacity(0.4) : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
              text.trimmingCharacters(in: .whitespaces).isEmpty
                ? Color.gray.opacity(0.35) : Color.black,
              in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding()
  }
}

@available(iOS 26.0, *)
struct TogglePanelTodoIntent: AppIntent {
  static let title: LocalizedStringResource = "Cocher une tâche"
  static let openAppWhenRun: Bool = false

  // Contrainte SnippetIntent : paramètres primitifs uniquement (String ici),
  // le système peut ré-exécuter l'intent plusieurs fois.
  @Parameter(title: "Identifiant")
  var todoID: String

  init() {}
  init(todoID: String) {
    self.todoID = todoID
  }

  func perform() async throws -> some IntentResult {
    ShortistNativeStore.toggleTodo(id: todoID)
    return .result()
  }
}

/// Seule action qui OUVRE l'app (bouton explicite « Ouvrir l'application »,
/// comme dans le panneau Flutter) — l'app s'ouvre sur PanelScreen.
@available(iOS 16.0, *)
struct OpenShortistAppIntent: AppIntent {
  static let title: LocalizedStringResource = "Ouvrir Shortist"
  static let openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    .result()
  }
}

// MARK: - Fallback iOS 16+ (sans snippet) : saisie via la carte système

@available(iOS 16.0, *)
struct QuickNoteIntent: AppIntent {
  static let title: LocalizedStringResource = "Note rapide"
  static let description = IntentDescription("Enregistre une note sans ouvrir l'application.")
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Note", requestValueDialog: "Quoi noter ?")
  var text: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    ShortistNativeStore.addNote(title: "Note", body: text)
    return .result(dialog: "Noté ✅")
  }
}

@available(iOS 16.0, *)
struct QuickTodoIntent: AppIntent {
  static let title: LocalizedStringResource = "Tâche rapide"
  static let description = IntentDescription("Ajoute une tâche To-Do sans ouvrir l'application.")
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Tâche", requestValueDialog: "Nouvelle tâche ?")
  var text: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    ShortistNativeStore.addTodo(text: text)
    return .result(dialog: "Ajouté ✅")
  }
}

// MARK: - App Shortcuts (visibles dans Raccourcis et Toucher le dos sans configuration)

// Un seul AppShortcutsProvider par app. iOS 26 requis car il référence
// OpenPanelIntent ; sur iOS 16–25, QuickNoteIntent / QuickTodoIntent restent
// disponibles dans l'app Raccourcis (création manuelle d'un raccourci).
@available(iOS 26.0, *)
struct ShortistShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenPanelIntent(),
      phrases: ["Ouvre le panneau de \(.applicationName)"],
      shortTitle: "Panneau",
      systemImageName: "rectangle.topthird.inset.filled"
    )
    AppShortcut(
      intent: QuickNoteIntent(),
      phrases: ["Note rapide avec \(.applicationName)"],
      shortTitle: "Note rapide",
      systemImageName: "square.and.pencil"
    )
  }
}
