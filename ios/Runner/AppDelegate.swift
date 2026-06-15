import Flutter
import UIKit
import EventKit
import WidgetKit

#if canImport(AppIntents)
import AppIntents
#endif

private let kAppGroup = "group.com.gnemmialex.tapbacknote"
private let kWidgetKeys = ["flutter.tbc_todos", "flutter.tbc_notes", "flutter.tbc_reading"]

// MARK: - App Delegate

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Accès au Calendrier iPhone (synchro de l'onglet Agenda).
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Le provider (défini dans QuickPanel.swift) référence le snippet iOS 26.
    if #available(iOS 26.0, *) {
      ShortistShortcuts.updateAppShortcutParameters()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShortistPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "com.gnemmialex.tapbacknote/tapback",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {

      case "openAccessibility":
        // Réglages → Accessibilité → Toucher → Toucher le dos de l'appareil
        let deepLink = "App-prefs:Accessibility&path=TOUCH/BACK_TAP"
        let fallback = "App-prefs:Accessibility"
        if let url = URL(string: deepLink) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let url = URL(string: fallback) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)

      case "openShortcuts":
        // Ouvre l'application Raccourcis iOS
        if let url = URL(string: "shortcuts://") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)

      case "minimizeApp":
        // Renvoie l'app en arrière-plan : l'utilisateur retrouve l'écran
        // d'accueil de l'iPhone quand il ferme la petite fenêtre.
        // ⚠️ Sélecteur non documenté par Apple : à surveiller lors de la review App Store.
        DispatchQueue.main.async {
          UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        }
        result(nil)

      // ── Calendrier (EventKit) ──────────────────────────────────────
      // L'Agenda de l'app lit/écrit le vrai Calendrier de l'iPhone :
      // tous les comptes y apparaissent (iCloud, Google, Outlook…), donc
      // l'utilisateur peut choisir « une autre application » en visant
      // l'un de ces calendriers via calListCalendars / calendarId.

      case "calHasAccess":
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
          result(status == .fullAccess)
        } else {
          result(status == .authorized)
        }

      case "calRequestAccess":
        let done: (Bool, Error?) -> Void = { granted, _ in
          DispatchQueue.main.async {
            // Un store créé AVANT l'autorisation peut ne pas voir les
            // calendriers : on le purge une fois l'accès accordé.
            if granted { self.eventStore.reset() }
            result(granted)
          }
        }
        if #available(iOS 17.0, *) {
          self.eventStore.requestFullAccessToEvents(completion: done)
        } else {
          self.eventStore.requestAccess(to: .event, completion: done)
        }

      case "calListCalendars":
        // Calendriers dans lesquels on peut écrire, avec leur compte
        // d'origine (iCloud, Gmail, Outlook…) pour que l'utilisateur
        // choisisse où créer ses événements.
        let calendars = self.eventStore.calendars(for: .event)
          .filter { $0.allowsContentModifications }
          .map { cal in
            [
              "id": cal.calendarIdentifier,
              "title": cal.title,
              "source": cal.source?.title ?? "",
              "isDefault": cal.calendarIdentifier ==
                self.eventStore.defaultCalendarForNewEvents?.calendarIdentifier,
            ] as [String: Any]
          }
        result(calendars)

      case "calFetchEvents":
        guard
          let args = call.arguments as? [String: Any],
          let startMs = (args["startMs"] as? NSNumber)?.doubleValue,
          let endMs = (args["endMs"] as? NSNumber)?.doubleValue
        else { result([]); return }
        let predicate = self.eventStore.predicateForEvents(
          withStart: Date(timeIntervalSince1970: startMs / 1000),
          end: Date(timeIntervalSince1970: endMs / 1000),
          calendars: nil
        )
        let events = self.eventStore.events(matching: predicate).map { ev in
          [
            "id": ev.eventIdentifier ?? "",
            "title": ev.title ?? "",
            "start": (ev.startDate ?? Date()).timeIntervalSince1970 * 1000,
            "notes": ev.notes ?? "",
            "calendar": ev.calendar?.title ?? "",
            "editable": ev.calendar?.allowsContentModifications ?? false,
          ] as [String: Any]
        }
        result(events)

      case "calAddEvent":
        guard
          let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let startMs = (args["startMs"] as? NSNumber)?.doubleValue,
          let endMs = (args["endMs"] as? NSNumber)?.doubleValue
        else { result(nil); return }
        let event = EKEvent(eventStore: self.eventStore)
        event.title = title
        event.startDate = Date(timeIntervalSince1970: startMs / 1000)
        event.endDate = Date(timeIntervalSince1970: endMs / 1000)
        if let notes = args["notes"] as? String, !notes.isEmpty {
          event.notes = notes
        }
        // Calendrier choisi par l'utilisateur, sinon celui par défaut,
        // sinon le premier accessible en écriture (defaultCalendar peut
        // être nil sur certains comptes).
        var target: EKCalendar?
        if let calId = args["calendarId"] as? String, !calId.isEmpty {
          target = self.eventStore.calendar(withIdentifier: calId)
        }
        event.calendar = target
          ?? self.eventStore.defaultCalendarForNewEvents
          ?? self.eventStore.calendars(for: .event)
            .first(where: { $0.allowsContentModifications })
        do {
          try self.eventStore.save(event, span: .thisEvent, commit: true)
          result(event.eventIdentifier)
        } catch {
          result(nil)
        }

      case "calUpdateEvent":
        guard
          let args = call.arguments as? [String: Any],
          let eventId = args["eventId"] as? String,
          let event = self.eventStore.event(withIdentifier: eventId)
        else { result(false); return }
        if let title = args["title"] as? String { event.title = title }
        if let startMs = (args["startMs"] as? NSNumber)?.doubleValue,
           let endMs = (args["endMs"] as? NSNumber)?.doubleValue {
          event.startDate = Date(timeIntervalSince1970: startMs / 1000)
          event.endDate = Date(timeIntervalSince1970: endMs / 1000)
        }
        if let notes = args["notes"] as? String {
          event.notes = notes.isEmpty ? nil : notes
        }
        do {
          try self.eventStore.save(event, span: .thisEvent, commit: true)
          result(true)
        } catch {
          result(false)
        }

      case "calDeleteEvent":
        guard
          let args = call.arguments as? [String: Any],
          let eventId = args["eventId"] as? String,
          let event = self.eventStore.event(withIdentifier: eventId)
        else { result(false); return }
        do {
          try self.eventStore.remove(event, span: .thisEvent, commit: true)
          result(true)
        } catch {
          result(false)
        }

      // ── Widget Home Screen ─────────────────────────────────────────────
      // widgetSync : copie standard → App Group + recharge les timelines.
      // Appelé par store.dart après chaque sauvegarde.
      case "widgetSync":
        let groupDef = UserDefaults(suiteName: kAppGroup)
        for key in kWidgetKeys {
          if let raw = UserDefaults.standard.string(forKey: key) {
            groupDef?.set(raw, forKey: key)
          }
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)

      // widgetMerge : fusionne App Group → standard (éléments ajoutés via widget).
      // Appelé par store.dart avant prefs.reload() au premier plan.
      case "widgetMerge":
        guard let groupDef = UserDefaults(suiteName: kAppGroup) else {
          result(nil); return
        }
        for key in kWidgetKeys {
          guard
            let grpRaw = groupDef.string(forKey: key), !grpRaw.isEmpty,
            let grpData = grpRaw.data(using: .utf8),
            let grpList = try? JSONSerialization.jsonObject(with: grpData) as? [[String: Any]]
          else { continue }

          let stdRaw = UserDefaults.standard.string(forKey: key) ?? ""
          var stdList: [[String: Any]] = []
          if !stdRaw.isEmpty,
             let stdData = stdRaw.data(using: .utf8),
             let parsed = try? JSONSerialization.jsonObject(with: stdData) as? [[String: Any]] {
            stdList = parsed
          }

          let stdIds = Set(stdList.compactMap { $0["id"] as? String })
          let newItems = grpList.filter { !(stdIds.contains($0["id"] as? String ?? "")) }
          guard !newItems.isEmpty else { continue }

          var merged = stdList + newItems
          merged.sort { ($0["createdAt"] as? String ?? "") > ($1["createdAt"] as? String ?? "") }
          if let data = try? JSONSerialization.data(withJSONObject: merged),
             let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: key)
            groupDef.set(raw, forKey: key)
          }
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

// L'ancienne approche d'affichage (OpenShortistIntent openAppWhenRun = true,
// puis URL scheme shortist://tapback) qui amenait l'app au premier plan a été
// entièrement supprimée. Le panneau au-dessus des autres apps est rendu par
// le système via QuickPanel.swift (OpenPanelIntent + PanelSnippetIntent).
