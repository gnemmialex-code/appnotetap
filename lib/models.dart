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
  String description; // détail optionnel, éditable depuis l'accueil de l'app
  bool done;
  DateTime? doneAt; // date à laquelle la tâche a été marquée « Fait »

  Todo({
    required this.id,
    required this.createdAt,
    required this.text,
    this.description = '',
    this.done = false,
    this.doneAt,
  });

  /// Durée pendant laquelle une tâche cochée reste visible dans la
  /// petite fenêtre rapide avant d'en disparaître (elle reste dans
  /// l'historique de l'accueil de l'app).
  static const panelLinger = Duration(minutes: 10);

  /// Vrai si la tâche est terminée depuis plus de 24 h
  /// (donc à retirer de la liste active mais à conserver dans l'archive).
  bool get archived =>
      done && doneAt != null && DateTime.now().difference(doneAt!).inHours >= 24;

  /// Visible dans la petite fenêtre : non faite, ou faite depuis < 10 min.
  bool get visibleInQuickPanel =>
      !done ||
      (doneAt != null && DateTime.now().difference(doneAt!) < panelLinger);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'description': description,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String? ?? '',
        description: j['description'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        doneAt: (j['doneAt'] as String?) != null
            ? DateTime.parse(j['doneAt'] as String)
            : null,
      );
}

/// Événement d'agenda. `deviceId` est l'identifiant EventKit quand
/// l'événement vit dans le vrai Calendrier de l'iPhone (Agenda synchronisé).
/// `calendarName` / `editable` ne sont remplis que pour ces événements-là.
class CalEvent {
  final String id;
  String title;
  DateTime when;
  String note;
  String? deviceId;
  String calendarName;
  bool editable;

  CalEvent({
    required this.id,
    required this.title,
    required this.when,
    this.note = '',
    this.deviceId,
    this.calendarName = '',
    this.editable = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'note': note,
        'deviceId': deviceId,
      };

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        when: DateTime.parse(j['when'] as String),
        note: j['note'] as String? ?? '',
        deviceId: j['deviceId'] as String?,
      );
}

/// Fiche du Carnet : note détaillée avec date/heure et image optionnelles.
class CarnetEntry {
  final String id;
  final DateTime createdAt;
  String title;
  String note;
  DateTime? when;
  String? imageB64; // image encodée en base64 (JPEG)

  CarnetEntry({
    required this.id,
    required this.createdAt,
    required this.title,
    this.note = '',
    this.when,
    this.imageB64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'note': note,
        'when': when?.toIso8601String(),
        'imageB64': imageB64,
      };

  factory CarnetEntry.fromJson(Map<String, dynamic> j) => CarnetEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        when: (j['when'] as String?) != null
            ? DateTime.parse(j['when'] as String)
            : null,
        imageB64: j['imageB64'] as String?,
      );
}

/// Élément « À lire plus tard » : un lien ou un texte, avec rappel optionnel.
class ReadItem {
  final String id;
  final DateTime createdAt;
  String text;
  DateTime? remindAt;
  bool done;
  String? imageB64; // image optionnelle encodée en base64

  ReadItem({
    required this.id,
    required this.createdAt,
    required this.text,
    this.remindAt,
    this.done = false,
    this.imageB64,
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
        'imageB64': imageB64,
      };

  factory ReadItem.fromJson(Map<String, dynamic> j) => ReadItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String? ?? '',
        remindAt: (j['remindAt'] as String?) != null
            ? DateTime.parse(j['remindAt'] as String)
            : null,
        done: j['done'] as bool? ?? false,
        imageB64: j['imageB64'] as String?,
      );
}
