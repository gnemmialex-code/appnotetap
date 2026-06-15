// Notifications locales planifiées (rappels « À lire plus tard »).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// À appeler une fois au démarrage (dans main).
  static Future<void> init() async {
    if (_ready) return;
    // Fuseau horaire local (pour planifier à la bonne heure).
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {/* défaut UTC si indéterminé */}

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// Demande l'autorisation (iOS + Android 13+).
  static Future<void> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reading_reminders',
      'Rappels À lire',
      channelDescription: 'Rappels pour les éléments à lire plus tard',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Planifie un rappel. `id` doit être un entier stable (hash de l'item).
  static Future<void> schedule({
    required int id,
    required String body,
    required DateTime when,
  }) async {
    if (!_ready) await init();
    if (when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '📖 À lire',
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification non planifiée: $e');
    }
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }

  static const _noteDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'note_reminders',
      'Rappels notes rapides',
      channelDescription: 'Rappels horaires pour les notes rapides — suppression après 24h',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static int _noteHourlyId(int baseId, int hour) => baseId * 24 + hour;

  /// Planifie jusqu'à 24 rappels horaires (1 par heure) pour une note rapide.
  /// Appeler cancelNoteReminders quand la note est supprimée.
  static Future<void> scheduleNoteReminders({
    required int baseId,
    required String title,
    required DateTime createdAt,
  }) async {
    if (!_ready) await init();
    final now = DateTime.now();
    for (int h = 1; h <= 24; h++) {
      final when = createdAt.add(Duration(hours: h));
      if (when.isBefore(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: _noteHourlyId(baseId, h),
          title: '⚡ Note rapide',
          body: title,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: _noteDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Note notif h$h non planifiée : $e');
      }
    }
  }

  /// Annule tous les rappels horaires d'une note rapide.
  static Future<void> cancelNoteReminders(int baseId) async {
    if (!_ready) return;
    for (int h = 1; h <= 24; h++) {
      await _plugin.cancel(id: _noteHourlyId(baseId, h));
    }
  }
}
