// Persistance locale via shared_preferences (JSON encodé).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Source de vérité de l'app. `ChangeNotifier` pour rafraîchir l'UI.
class Store extends ChangeNotifier {
  static const _kNotes = 'tbc_notes';
  static const _kTodos = 'tbc_todos';
  static const _kReading = 'tbc_reading';
  static const _kEvents = 'tbc_events';
  static const _kCarnet = 'tbc_carnet';
  static const _kProfile = 'tbc_profile';
  static const _kBackTapDone = 'tbc_back_tap_done';
  static const _kPanelWallpaper = 'tbc_panel_wallpaper';

  final List<Note> notes = [];
  final List<Todo> todos = [];
  final List<ReadItem> reading = [];
  final List<CalEvent> events = [];
  final List<CarnetEntry> carnet = [];

  // Profil utilisateur
  String profileName = '';
  String profileEmail = '';
  String? profileAvatarB64;

  bool backTapSetupDone = false;

  /// Capture d'écran de l'accueil de l'utilisateur, affichée derrière la
  /// fenêtre rapide (iOS ne permet pas un vrai fond transparent).
  String? panelWallpaperB64;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Le panneau système (App Intents natifs, ios/Runner/QuickPanel.swift)
    // écrit directement dans UserDefaults pendant que l'app est en
    // arrière-plan : on resynchronise le cache avant de lire, sinon la
    // prochaine sauvegarde écraserait ces ajouts.
    await prefs.reload();
    notes
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kNotes), Note.fromJson));
    todos
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kTodos), Todo.fromJson));
    reading
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kReading), ReadItem.fromJson));
    events
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kEvents), CalEvent.fromJson));
    carnet
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kCarnet), CarnetEntry.fromJson));
    final pr = prefs.getString(_kProfile);
    if (pr != null && pr.isNotEmpty) {
      final m = jsonDecode(pr) as Map<String, dynamic>;
      profileName = m['name'] as String? ?? '';
      profileEmail = m['email'] as String? ?? '';
      profileAvatarB64 = m['avatar'] as String?;
    }
    backTapSetupDone = prefs.getBool(_kBackTapDone) ?? false;
    final wp = prefs.getString(_kPanelWallpaper);
    panelWallpaperB64 = (wp != null && wp.isNotEmpty) ? wp : null;
    _loaded = true;
    notifyListeners();
  }

  /// Enregistre (ou retire si `null`) la capture d'écran utilisée comme
  /// fond derrière la fenêtre rapide.
  Future<void> savePanelWallpaper(String? b64) async {
    panelWallpaperB64 = b64;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (b64 == null) {
      await prefs.remove(_kPanelWallpaper);
    } else {
      await prefs.setString(_kPanelWallpaper, b64);
    }
  }

  Future<void> markBackTapSetupDone() async {
    backTapSetupDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBackTapDone, true);
  }

  static List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) f) {
    if (raw == null || raw.isEmpty) return [];
    final data = jsonDecode(raw) as List;
    return data.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save(String key, List items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // --- Notes ---
  Future<void> addNote(Note n) async {
    notes.insert(0, n);
    notifyListeners();
    await _save(_kNotes, notes);
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kNotes, notes);
  }

  // --- Todos ---
  Future<void> addTodo(Todo t) async {
    todos.insert(0, t);
    notifyListeners();
    await _save(_kTodos, todos);
  }

  /// Les 5 dernières tâches à montrer dans la petite fenêtre rapide
  /// (les tâches cochées depuis plus de 10 min en sont exclues).
  List<Todo> get quickPanelTodos =>
      todos.where((t) => t.visibleInQuickPanel).take(5).toList();

  Future<void> updateTodo(String id, {String? text, String? description}) async {
    final t = todos.firstWhere((e) => e.id == id);
    if (text != null && text.isNotEmpty) t.text = text;
    if (description != null) t.description = description;
    notifyListeners();
    await _save(_kTodos, todos);
  }

  Future<void> toggleTodo(String id) async {
    final t = todos.firstWhere((e) => e.id == id);
    t.done = !t.done;
    t.doneAt = t.done ? DateTime.now() : null;
    notifyListeners();
    await _save(_kTodos, todos);
  }

  Future<void> deleteTodo(String id) async {
    todos.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kTodos, todos);
  }

  // --- À lire ---
  Future<void> addReading(ReadItem r) async {
    reading.insert(0, r);
    notifyListeners();
    await _save(_kReading, reading);
  }

  Future<void> toggleReading(String id) async {
    final r = reading.firstWhere((e) => e.id == id);
    r.done = !r.done;
    notifyListeners();
    await _save(_kReading, reading);
  }

  Future<void> deleteReading(String id) async {
    reading.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kReading, reading);
  }

  // --- Agenda ---
  Future<void> addEvent(CalEvent e) async {
    events.add(e);
    events.sort((a, b) => a.when.compareTo(b.when));
    notifyListeners();
    await _save(_kEvents, events);
  }

  Future<void> deleteEvent(String id) async {
    events.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kEvents, events);
  }

  // --- Carnet ---
  Future<void> addCarnet(CarnetEntry c) async {
    carnet.insert(0, c);
    notifyListeners();
    await _save(_kCarnet, carnet);
  }

  Future<void> deleteCarnet(String id) async {
    carnet.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kCarnet, carnet);
  }

  // --- Profil ---
  Future<void> saveProfile(
      {String? name, String? email, String? avatarB64}) async {
    if (name != null) profileName = name;
    if (email != null) profileEmail = email;
    if (avatarB64 != null) profileAvatarB64 = avatarB64;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kProfile,
        jsonEncode({
          'name': profileName,
          'email': profileEmail,
          'avatar': profileAvatarB64,
        }));
  }
}

/// Instance globale partagée par toute l'application (main.dart + demo_page.dart).
final store = Store();
