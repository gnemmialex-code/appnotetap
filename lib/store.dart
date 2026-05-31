// Persistance locale via shared_preferences (JSON encodé).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Source de vérité de l'app. `ChangeNotifier` pour rafraîchir l'UI.
class Store extends ChangeNotifier {
  static const _kNotes = 'tbc_notes';
  static const _kTodos = 'tbc_todos';
  static const _kSearches = 'tbc_searches';

  final List<Note> notes = [];
  final List<Todo> todos = [];
  final List<SearchEntry> searches = [];

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
    searches
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kSearches), SearchEntry.fromJson));
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

  // --- Searches ---
  Future<void> addSearch(SearchEntry s) async {
    searches.insert(0, s);
    notifyListeners();
    await _save(_kSearches, searches);
  }

  Future<void> deleteSearch(String id) async {
    searches.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save(_kSearches, searches);
  }
}
