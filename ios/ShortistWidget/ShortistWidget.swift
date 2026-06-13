// ShortistWidget.swift — Widgets Home Screen (WidgetKit, iOS 14+)
//
// 3 widgets disponibles :
//   • ShortistTodos   — 5 tâches actives + bouton d'ajout
//   • ShortistNotes   — 5 dernières notes  + bouton d'ajout
//   • ShortistCombined— 3 tâches + 2 notes + boutons d'ajout
//
// Données : lues dans l'App Group UserDefaults "group.com.gnemmialex.tapbacknote"
//   (même JSON que store.dart, clés "flutter.tbc_*").
//   La synchro se fait via AppDelegate.widgetSync (après chaque save Flutter)
//   et via les intents ci-dessous (ajouts/coches depuis le widget).
//
// XCODE — Étapes obligatoires (à faire une seule fois) :
//   1. File › New › Target › Widget Extension → nom : ShortistWidget
//      - Décocher "Include Configuration Intent"
//      - Deployment target : iOS 16.0
//   2. Dans l'onglet Signing & Capabilities des DEUX targets (Runner + ShortistWidget) :
//      - Ajouter "App Groups" → group.com.gnemmialex.tapbacknote
//   3. Ajouter ce fichier au target ShortistWidget (Target Membership).
//   4. Supprimer le fichier Swift généré automatiquement par Xcode.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Stockage partagé (App Group)

private let kAppGroup   = "group.com.gnemmialex.tapbacknote"
private let kTodosKey   = "flutter.tbc_todos"
private let kNotesKey   = "flutter.tbc_notes"
private let kReadingKey = "flutter.tbc_reading"

private func groupDefaults() -> UserDefaults { UserDefaults(suiteName: kAppGroup) ?? .standard }

private func loadJSON(_ key: String) -> [[String: Any]] {
  guard
    let raw  = groupDefaults().string(forKey: key),
    let data = raw.data(using: .utf8),
    let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
  else { return [] }
  return list
}

private func saveJSON(_ key: String, _ list: [[String: Any]]) {
  guard
    let data = try? JSONSerialization.data(withJSONObject: list),
    let raw  = String(data: data, encoding: .utf8)
  else { return }
  groupDefaults().set(raw, forKey: key)
}

private func newId() -> String { String(Int(Date().timeIntervalSince1970 * 1_000_000), radix: 36) }

private func dartDate(_ date: Date) -> String {
  let f = DateFormatter()
  f.locale = Locale(identifier: "en_US_POSIX")
  f.timeZone = .current
  f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
  return f.string(from: date)
}

// MARK: - Modèles légers

struct WidgetTodo: Identifiable {
  let id: String
  let text: String
  let done: Bool
}

struct WidgetNote: Identifiable {
  let id: String
  let title: String
  let body: String
}

private func activeTodos() -> [WidgetTodo] {
  loadJSON(kTodosKey)
    .filter { !($0["done"] as? Bool ?? false) }
    .prefix(5)
    .map { WidgetTodo(id: $0["id"] as? String ?? "",
                      text: $0["text"] as? String ?? "",
                      done: false) }
}

private func recentNotes() -> [WidgetNote] {
  loadJSON(kNotesKey)
    .prefix(5)
    .map { WidgetNote(id: $0["id"] as? String ?? "",
                      title: $0["title"] as? String ?? "",
                      body: $0["body"] as? String ?? "") }
}

// MARK: - App Intents (widget extension)

@available(iOS 16.0, *)
struct WAddTodoIntent: AppIntent {
  static let title: LocalizedStringResource = "Ajouter une tâche (widget)"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Tâche", requestValueDialog: "Nouvelle tâche ?")
  var text: String

  func perform() async throws -> some IntentResult {
    var todos = loadJSON(kTodosKey)
    todos.insert([
      "id": newId(), "createdAt": dartDate(Date()),
      "text": text, "description": "", "done": false, "doneAt": NSNull()
    ], at: 0)
    saveJSON(kTodosKey, todos)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

@available(iOS 16.0, *)
struct WAddNoteIntent: AppIntent {
  static let title: LocalizedStringResource = "Ajouter une note (widget)"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Note", requestValueDialog: "Quoi noter ?")
  var text: String

  func perform() async throws -> some IntentResult {
    var notes = loadJSON(kNotesKey)
    notes.insert([
      "id": newId(), "createdAt": dartDate(Date()),
      "title": text.isEmpty ? "Note" : text, "body": "", "plan": [String]()
    ], at: 0)
    saveJSON(kNotesKey, notes)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

@available(iOS 16.0, *)
struct WAddReadingIntent: AppIntent {
  static let title: LocalizedStringResource = "À lire (widget)"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Lien ou texte", requestValueDialog: "Quoi lire plus tard ?")
  var text: String

  func perform() async throws -> some IntentResult {
    var reading = loadJSON(kReadingKey)
    reading.insert([
      "id": newId(), "createdAt": dartDate(Date()),
      "text": text, "remindAt": NSNull(), "done": false
    ], at: 0)
    saveJSON(kReadingKey, reading)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

@available(iOS 16.0, *)
struct WToggleTodoIntent: AppIntent {
  static let title: LocalizedStringResource = "Cocher une tâche (widget)"
  static let openAppWhenRun: Bool = false

  @Parameter(title: "ID")
  var todoID: String

  init() {}
  init(todoID: String) { self.todoID = todoID }

  func perform() async throws -> some IntentResult {
    var todos = loadJSON(kTodosKey)
    guard let i = todos.firstIndex(where: { $0["id"] as? String == todoID }) else {
      return .result()
    }
    let nowDone = !(todos[i]["done"] as? Bool ?? false)
    todos[i]["done"] = nowDone
    todos[i]["doneAt"] = nowDone ? dartDate(Date()) : NSNull()
    saveJSON(kTodosKey, todos)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

// MARK: - Timeline

struct ShortistEntry: TimelineEntry {
  let date: Date
  let todos: [WidgetTodo]
  let notes: [WidgetNote]
}

struct ShortistProvider: TimelineProvider {
  func placeholder(in _: Context) -> ShortistEntry {
    ShortistEntry(date: Date(),
      todos: [WidgetTodo(id: "1", text: "Exemple de tâche", done: false)],
      notes: [WidgetNote(id: "1", title: "Exemple de note", body: "Texte de la note")])
  }
  func getSnapshot(in _: Context, completion: @escaping (ShortistEntry) -> Void) {
    completion(ShortistEntry(date: Date(), todos: activeTodos(), notes: recentNotes()))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<ShortistEntry>) -> Void) {
    let entry = ShortistEntry(date: Date(), todos: activeTodos(), notes: recentNotes())
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

// MARK: - Vues communes

private struct WidgetHeader: View {
  let icon: String
  let label: String
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 12, weight: .bold))
      Text(label).font(.system(size: 13, weight: .bold))
      Spacer()
    }
  }
}

private struct EmptyLabel: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .multilineTextAlignment(.center)
  }
}

// MARK: - Widget 1 : To-Do uniquement

struct TodosWidgetView: View {
  let entry: ShortistEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Header + bouton +
      HStack {
        WidgetHeader(icon: "checklist", label: "To-Do")
        if #available(iOS 17.0, *) {
          Button(intent: WAddTodoIntent()) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 20))
              .foregroundStyle(.primary)
          }
          .buttonStyle(.plain)
        }
      }

      Divider()

      if entry.todos.isEmpty {
        EmptyLabel(text: "Aucune tâche à faire")
      } else {
        ForEach(entry.todos) { todo in
          HStack(spacing: 8) {
            if #available(iOS 17.0, *) {
              Button(intent: WToggleTodoIntent(todoID: todo.id)) {
                Image(systemName: "circle")
                  .foregroundStyle(.secondary)
                  .font(.system(size: 15))
              }
              .buttonStyle(.plain)
            } else {
              Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            }
            Text(todo.text)
              .font(.system(size: 13, weight: .medium))
              .lineLimit(1)
            Spacer(minLength: 0)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .containerBackground(.background, for: .widget)
  }
}

struct TodosWidget: Widget {
  let kind = "ShortistTodos"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ShortistProvider()) { entry in
      TodosWidgetView(entry: entry)
    }
    .configurationDisplayName("To-Do")
    .description("Vos 5 prochaines tâches avec ajout rapide.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Widget 2 : Notes uniquement

struct NotesWidgetView: View {
  let entry: ShortistEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        WidgetHeader(icon: "square.and.pencil", label: "Notes")
        if #available(iOS 17.0, *) {
          Button(intent: WAddNoteIntent()) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 20))
              .foregroundStyle(.primary)
          }
          .buttonStyle(.plain)
        }
      }

      Divider()

      if entry.notes.isEmpty {
        EmptyLabel(text: "Aucune note")
      } else {
        ForEach(entry.notes) { note in
          VStack(alignment: .leading, spacing: 1) {
            Text(note.title)
              .font(.system(size: 13, weight: .semibold))
              .lineLimit(1)
            if !note.body.isEmpty {
              Text(note.body)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .padding(.vertical, 2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .containerBackground(.background, for: .widget)
  }
}

struct NotesWidget: Widget {
  let kind = "ShortistNotes"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ShortistProvider()) { entry in
      NotesWidgetView(entry: entry)
    }
    .configurationDisplayName("Notes")
    .description("Vos 5 dernières notes avec ajout rapide.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Widget 3 : Tout en un (To-Do + Notes)

struct CombinedWidgetView: View {
  let entry: ShortistEntry
  @Environment(\.widgetFamily) var family

  var todosToShow: [WidgetTodo] {
    Array(entry.todos.prefix(family == .systemLarge ? 5 : 3))
  }
  var notesToShow: [WidgetNote] {
    Array(entry.notes.prefix(family == .systemLarge ? 4 : 2))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Text("Shortist")
          .font(.system(size: 14, weight: .heavy))
        Spacer()
        if #available(iOS 17.0, *) {
          HStack(spacing: 12) {
            Button(intent: WAddNoteIntent()) {
              Image(systemName: "square.and.pencil").font(.system(size: 16))
            }
            .buttonStyle(.plain)
            Button(intent: WAddTodoIntent()) {
              Image(systemName: "checklist").font(.system(size: 16))
            }
            .buttonStyle(.plain)
            Button(intent: WAddReadingIntent()) {
              Image(systemName: "bookmark").font(.system(size: 16))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.bottom, 6)

      Divider()

      // Section To-Do
      if !todosToShow.isEmpty {
        Text("TO-DO")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)
          .padding(.top, 6)
          .padding(.bottom, 2)
        ForEach(todosToShow) { todo in
          HStack(spacing: 6) {
            if #available(iOS 17.0, *) {
              Button(intent: WToggleTodoIntent(todoID: todo.id)) {
                Image(systemName: "circle")
                  .font(.system(size: 13))
                  .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
            } else {
              Image(systemName: "circle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            Text(todo.text)
              .font(.system(size: 12, weight: .medium))
              .lineLimit(1)
            Spacer(minLength: 0)
          }
          .padding(.vertical, 2)
        }
      }

      // Section Notes
      if !notesToShow.isEmpty {
        if !todosToShow.isEmpty {
          Divider().padding(.vertical, 5)
        } else {
          Spacer().frame(height: 6)
        }
        Text("NOTES")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)
          .padding(.bottom, 2)
        ForEach(notesToShow) { note in
          Text(note.title)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.vertical, 2)
        }
      }

      if todosToShow.isEmpty && notesToShow.isEmpty {
        EmptyLabel(text: "Aucun contenu.\nAjoute une tâche ou une note.")
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .containerBackground(.background, for: .widget)
  }
}

struct CombinedWidget: Widget {
  let kind = "ShortistCombined"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ShortistProvider()) { entry in
      CombinedWidgetView(entry: entry)
    }
    .configurationDisplayName("Shortist — Tout en un")
    .description("Tâches et notes dans un seul widget, avec ajout rapide.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

// MARK: - Bundle

@main
struct ShortistWidgetBundle: WidgetBundle {
  var body: some Widget {
    TodosWidget()
    NotesWidget()
    CombinedWidget()
  }
}
