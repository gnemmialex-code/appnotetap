import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Déclencheur interne (bouton « Tester Tap Back » et page démo).
/// Le vrai Back Tap n'arrive plus jamais ici : il passe par le snippet
/// App Intents natif (ios/Runner/QuickPanel.swift), rendu par le système
/// par-dessus l'app en cours, sans ouvrir celle-ci.
final tapBackTrigger = ValueNotifier<int>(0);

const _channel = MethodChannel('com.gnemmialex.tapbacknote/tapback');

Future<void> openAccessibilitySettings() async {
  try {
    await _channel.invokeMethod('openAccessibility');
  } catch (_) {}
}

Future<void> openShortcutsApp() async {
  try {
    await _channel.invokeMethod('openShortcuts');
  } catch (_) {}
}

/// Renvoie l'app en arrière-plan (retour à l'écran d'accueil de l'iPhone).
/// Utilisé quand on ferme la petite fenêtre rapide.
Future<void> minimizeApp() async {
  try {
    await _channel.invokeMethod('minimizeApp');
  } catch (_) {}
}

// ── Calendrier iPhone (EventKit) ────────────────────────────────────────────
// L'Agenda de l'app se synchronise avec le vrai Calendrier via ces appels
// natifs (AppDelegate.swift). Sur le web / hors iOS, ils échouent en silence.

Future<bool> calendarHasAccess() async {
  try {
    return await _channel.invokeMethod('calHasAccess') as bool? ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> calendarRequestAccess() async {
  try {
    return await _channel.invokeMethod('calRequestAccess') as bool? ?? false;
  } catch (_) {
    return false;
  }
}

/// Calendriers de l'iPhone accessibles en écriture, tous comptes confondus
/// (iCloud, Google, Outlook…) : liste de maps {id, title, source, isDefault}.
Future<List<Map<String, dynamic>>> calendarListCalendars() async {
  try {
    final raw = await _channel.invokeMethod('calListCalendars') as List?;
    return (raw ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Événements du Calendrier entre deux dates (liste de maps
/// {id, title, start (ms epoch), notes, calendar, editable}).
Future<List<Map<String, dynamic>>> calendarFetchEvents(
    DateTime start, DateTime end) async {
  try {
    final raw = await _channel.invokeMethod('calFetchEvents', {
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    }) as List?;
    return (raw ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Crée un événement dans le Calendrier (dans `calendarId` si fourni,
/// sinon le calendrier par défaut) ; renvoie son identifiant EventKit.
Future<String?> calendarAddEvent(
    {required String title,
    required DateTime when,
    String note = '',
    String? calendarId}) async {
  try {
    return await _channel.invokeMethod('calAddEvent', {
      'title': title,
      'startMs': when.millisecondsSinceEpoch,
      'endMs': when.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'notes': note,
      'calendarId': calendarId ?? '',
    }) as String?;
  } catch (_) {
    return null;
  }
}

/// Modifie un événement existant du Calendrier.
Future<bool> calendarUpdateEvent(
    {required String eventId,
    required String title,
    required DateTime when,
    String note = ''}) async {
  try {
    return await _channel.invokeMethod('calUpdateEvent', {
          'eventId': eventId,
          'title': title,
          'startMs': when.millisecondsSinceEpoch,
          'endMs': when.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          'notes': note,
        }) as bool? ??
        false;
  } catch (_) {
    return false;
  }
}

Future<bool> calendarDeleteEvent(String eventId) async {
  try {
    return await _channel.invokeMethod('calDeleteEvent', {'eventId': eventId})
            as bool? ??
        false;
  } catch (_) {
    return false;
  }
}
