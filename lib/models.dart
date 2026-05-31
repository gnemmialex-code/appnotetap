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

  Todo({
    required this.id,
    required this.createdAt,
    required this.text,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'done': done,
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

class SearchEntry {
  final String id;
  final DateTime createdAt;
  final String query;
  final String type; // "Définition" | "Explication"
  final String term;
  final String body;
  final String source;
  final String? url;

  SearchEntry({
    required this.id,
    required this.createdAt,
    required this.query,
    required this.type,
    required this.term,
    required this.body,
    required this.source,
    this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'query': query,
        'type': type,
        'term': term,
        'body': body,
        'source': source,
        'url': url,
      };

  factory SearchEntry.fromJson(Map<String, dynamic> j) => SearchEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        query: j['query'] as String? ?? '',
        type: j['type'] as String? ?? 'Explication',
        term: j['term'] as String? ?? '',
        body: j['body'] as String? ?? '',
        source: j['source'] as String? ?? '',
        url: j['url'] as String?,
      );
}
