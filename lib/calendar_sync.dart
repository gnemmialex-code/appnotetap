// Synchronisation de l'Agenda avec le vrai Calendrier de l'iPhone (EventKit).
//
// Une fois connecté (autorisation complète : lecture, ajout, modification,
// suppression) :
//  - l'Agenda affiche les événements du Calendrier (fenêtre -30 j → +2 ans),
//    tous comptes confondus (iCloud, Google, Outlook…) ;
//  - ajouter / modifier / supprimer un événement le fait directement dans le
//    Calendrier, dans le calendrier CHOISI par l'utilisateur (réglable) ;
//  - les changements faits ailleurs (app Calendrier, autres appareils)
//    apparaissent ici au prochain rafraîchissement (retour au premier plan).
//
// Hors iOS (web de développement) ou tant que l'accès n'est pas accordé,
// l'Agenda continue de fonctionner en local via `store.events`.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bridge.dart';
import 'models.dart';
import 'store.dart';

/// Un calendrier de l'iPhone dans lequel on peut écrire.
class DeviceCalendar {
  final String id;
  final String title;
  final String source; // compte d'origine : iCloud, Gmail, Outlook…
  final bool isDefault;
  const DeviceCalendar(
      {required this.id,
      required this.title,
      required this.source,
      required this.isDefault});
}

class CalendarSync extends ChangeNotifier {
  static const _kLinked = 'tbc_cal_linked';
  static const _kTargetId = 'tbc_cal_target_id';
  static const _kTargetName = 'tbc_cal_target_name';

  bool linked = false;
  bool busy = false;

  /// Calendrier dans lequel les nouveaux événements sont créés
  /// (null = calendrier par défaut de l'iPhone).
  String? targetCalendarId;
  String targetCalendarName = '';

  /// Événements du Calendrier iPhone, triés par date.
  final List<CalEvent> events = [];

  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (!available) return;
    final prefs = await SharedPreferences.getInstance();
    linked = (prefs.getBool(_kLinked) ?? false) && await calendarHasAccess();
    targetCalendarId = prefs.getString(_kTargetId);
    targetCalendarName = prefs.getString(_kTargetName) ?? '';
    if (linked) await refresh();
  }

  /// Demande l'accès complet au Calendrier (afficher, ajouter, modifier,
  /// supprimer) puis migre les événements locaux existants vers le vrai
  /// Calendrier : la synchro est totale dès la connexion.
  Future<bool> link() async {
    if (!available) return false;
    busy = true;
    notifyListeners();
    final granted = await calendarRequestAccess();
    if (!granted) {
      busy = false;
      notifyListeners();
      return false;
    }
    // Migration : les événements créés en local rejoignent le Calendrier.
    for (final ev in List<CalEvent>.from(store.events)) {
      final deviceId = await calendarAddEvent(
          title: ev.title,
          when: ev.when,
          note: ev.note,
          calendarId: targetCalendarId);
      if (deviceId != null) await store.deleteEvent(ev.id);
    }
    linked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLinked, true);
    await refresh();
    busy = false;
    notifyListeners();
    return true;
  }

  /// Calendriers de l'iPhone accessibles en écriture (tous comptes).
  Future<List<DeviceCalendar>> calendars() async {
    final raw = await calendarListCalendars();
    return raw
        .map((m) => DeviceCalendar(
              id: m['id'] as String? ?? '',
              title: m['title'] as String? ?? '',
              source: m['source'] as String? ?? '',
              isDefault: m['isDefault'] as bool? ?? false,
            ))
        .toList();
  }

  /// Choisit le calendrier où créer les nouveaux événements
  /// (null = revenir au calendrier par défaut).
  Future<void> setTarget(DeviceCalendar? cal) async {
    targetCalendarId = cal?.id;
    targetCalendarName = cal == null
        ? ''
        : (cal.source.isEmpty ? cal.title : '${cal.title} (${cal.source})');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (cal == null) {
      await prefs.remove(_kTargetId);
      await prefs.remove(_kTargetName);
    } else {
      await prefs.setString(_kTargetId, cal.id);
      await prefs.setString(_kTargetName, targetCalendarName);
    }
  }

  Future<void> refresh() async {
    if (!linked) return;
    final now = DateTime.now();
    final raw = await calendarFetchEvents(
        now.subtract(const Duration(days: 30)),
        now.add(const Duration(days: 730)));
    events
      ..clear()
      ..addAll(raw.map((m) => CalEvent(
            id: m['id'] as String? ?? '',
            title: m['title'] as String? ?? '',
            when: DateTime.fromMillisecondsSinceEpoch(
                (m['start'] as num? ?? 0).toInt()),
            note: m['notes'] as String? ?? '',
            deviceId: m['id'] as String?,
            calendarName: m['calendar'] as String? ?? '',
            editable: m['editable'] as bool? ?? true,
          )))
      ..sort((a, b) => a.when.compareTo(b.when));
    notifyListeners();
  }

  Future<bool> add(
      {required String title, required DateTime when, String note = ''}) async {
    final deviceId = await calendarAddEvent(
        title: title, when: when, note: note, calendarId: targetCalendarId);
    await refresh();
    return deviceId != null;
  }

  Future<bool> update(CalEvent ev,
      {required String title, required DateTime when, String note = ''}) async {
    if (ev.deviceId == null) return false;
    final ok = await calendarUpdateEvent(
        eventId: ev.deviceId!, title: title, when: when, note: note);
    await refresh();
    return ok;
  }

  Future<bool> delete(CalEvent ev) async {
    if (ev.deviceId == null) return false;
    final ok = await calendarDeleteEvent(ev.deviceId!);
    events.removeWhere((e) => e.deviceId == ev.deviceId);
    notifyListeners();
    await refresh();
    return ok;
  }
}

/// Instance globale, initialisée au lancement (main.dart).
final calendarSync = CalendarSync();
