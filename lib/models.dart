// Modèles de données de TapBack Note.

class Note {
  final String id;
  final DateTime createdAt;
  String title;
  String body;
  List<String> plan;

  Note({
    required this.id,
    required this.createdAt,
    required this.title,
    this.body = '',
    List<String>? plan,
  }) : plan = plan ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'body': body,
        'plan': plan,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        title: j['title'] as String? ?? 'Note',
        body: j['body'] as String? ?? '',
        plan: (j['plan'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class Todo {
  final String id;
  final DateTime createdAt;
  String text;
  bool done;
  DateTime? doneAt; // date à laquelle la tâche a été marquée « Fait »

  Todo({
    required this.id,
    required this.createdAt,
    required this.text,
    this.done = false,
    this.doneAt,
  });

  /// Vrai si la tâche est terminée depuis plus de 24 h
  /// (donc à retirer de la liste active mais à conserver dans l'archive).
  bool get archived =>
      done && doneAt != null && DateTime.now().difference(doneAt!).inHours >= 24;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        doneAt: (j['doneAt'] as String?) != null
            ? DateTime.parse(j['doneAt'] as String)
            : null,
      );
}

/// Élément « À lire plus tard » : un lien ou un texte, avec rappel optionnel.
class ReadItem {
  final String id;
  final DateTime createdAt;
  String text;
  DateTime? remindAt;
  bool done;

  ReadItem({
    required this.id,
    required this.createdAt,
    required this.text,
    this.remindAt,
    this.done = false,
  });

  bool get isUrl => RegExp(r'^https?://', caseSensitive: false).hasMatch(text);

  /// Identifiant entier stable pour la notification (dérivé de l'id texte).
  int get notificationId => id.hashCode & 0x7fffffff;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'remindAt': remindAt?.toIso8601String(),
        'done': done,
      };

  factory ReadItem.fromJson(Map<String, dynamic> j) => ReadItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String? ?? '',
        remindAt: (j['remindAt'] as String?) != null
            ? DateTime.parse(j['remindAt'] as String)
            : null,
        done: j['done'] as bool? ?? false,
      );
}
