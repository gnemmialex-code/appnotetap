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

  final List<Note> notes = [];
  final List<Todo> todos = [];
  final List<ReadItem> reading = [];

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    notes
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kNotes), Note.fromJson));
    todos
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kTodos), Todo.fromJson));
    reading
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kReading), ReadItem.fromJson));
    _loaded = true;
    notifyListeners();
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
}
