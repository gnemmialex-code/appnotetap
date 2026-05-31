// TapBack Note — application Flutter (notes, to-dos, recherche rapide).
//
// Concept : un bouton « Tap Back » ouvre une fenêtre de commande en haut de
// l'écran avec 4 actions (Note, To-Do, Rechercher, Voir les notes), chacune
// s'ouvrant en place. Persistance locale via shared_preferences.
//
// NB : sur iOS, la police par défaut est San Francisco (police système).

import 'package:flutter/material.dart';

import 'models.dart';
import 'notifications.dart';
import 'store.dart';

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  await store.load();
  runApp(const TapBackApp());
}

// Palette
const _bg = Color(0xFF000000);
const _surface = Color(0x14FFFFFF);
const _textSecondary = Color(0x8CFFFFFF);

String _uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String formatStamp(DateTime d) {
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay(d, now)) return "Aujourd'hui $hm";
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier $hm';
  return '${d.day}/${d.month} $hm';
}

class TapBackApp extends StatelessWidget {
  const TapBackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        surface: _bg,
        primary: Colors.white,
      ),
    );
    return MaterialApp(
      title: 'TapBack Note',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  void _openCommand() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => CommandPanel(
        onOpenTab: (i) => setState(() => _tab = i),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final screens = [
          const NotesScreen(),
          const TodosScreen(),
          const ReadingScreen(),
        ];
        return Scaffold(
          body: SafeArea(bottom: false, child: screens[_tab]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCommand,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.bolt),
            label: const Text('Tap Back',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: const Color(0xFF111114),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.mic_none), label: 'Notes'),
              NavigationDestination(icon: Icon(Icons.checklist), label: 'To-Do'),
              NavigationDestination(
                  icon: Icon(Icons.bookmark_border), label: 'À lire'),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// Écrans (listes)
// ============================================================

class _Page extends StatelessWidget {
  final String title;
  final Widget child;
  const _Page({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Text(title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Empty(this.icon, this.title, this.message);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white24),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }
}

BoxDecoration get _card => BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final notes = store.notes;
    return _Page(
      title: 'Notes',
      child: notes.isEmpty
          ? const _Empty(Icons.mic_none, 'Aucune note',
              'Touche « Tap Back » puis Note pour créer une note.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final n = notes[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: _card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: _textSecondary,
                            onPressed: () => store.deleteNote(n.id),
                          ),
                        ],
                      ),
                      if (n.body.isNotEmpty)
                        Text(n.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _textSecondary)),
                      const SizedBox(height: 6),
                      Text(formatStamp(n.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});
  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final all = store.todos;
    // Liste active : tâches non terminées + terminées depuis moins de 24 h.
    final active = all.where((t) => !t.archived).toList();
    // Archive : toutes les tâches terminées (conservées avec leurs dates),
    // triées par date de réalisation décroissante.
    final done = all.where((t) => t.done).toList()
      ..sort((a, b) =>
          (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));

    final list = _showArchive ? done : active;

    return _Page(
      title: 'To-Do',
      child: Column(
        children: [
          _segmented(active.length, done.length),
          Expanded(
            child: list.isEmpty
                ? _emptyFor(_showArchive)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _showArchive
                        ? _archiveTile(list[i])
                        : _activeTile(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _segmented(int activeCount, int doneCount) {
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.black : _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          seg('À faire ($activeCount)', !_showArchive,
              () => setState(() => _showArchive = false)),
          seg('Terminées ($doneCount)', _showArchive,
              () => setState(() => _showArchive = true)),
        ],
      ),
    );
  }

  Widget _emptyFor(bool archive) => archive
      ? const _Empty(Icons.history, 'Aucune tâche terminée',
          'Les tâches cochées « Fait » sont conservées ici avec leurs dates.')
      : const _Empty(Icons.checklist, 'Aucune tâche',
          'Touche « Tap Back » puis To-Do pour ajouter une tâche.');

  Widget _activeTile(Todo t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: _card,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                t.done ? Icons.check_circle : Icons.radio_button_unchecked),
            color: t.done ? Colors.green : _textSecondary,
            onPressed: () => store.toggleTodo(t.id),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.text,
                  style: TextStyle(
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    color: t.done ? Colors.white38 : Colors.white,
                  ),
                ),
                if (t.done)
                  const Text('Fait · retiré de la liste dans 24 h',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: _textSecondary,
            onPressed: () => store.deleteTodo(t.id),
          ),
        ],
      ),
    );
  }

  Widget _archiveTile(Todo t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 10),
            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.text,
                    style: const TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(height: 4),
                Text('Créée : ${formatStamp(t.createdAt)}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white38)),
                if (t.doneAt != null)
                  Text('Faite : ${formatStamp(t.doneAt!)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.greenAccent)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: _textSecondary,
            onPressed: () => store.deleteTodo(t.id),
          ),
        ],
      ),
    );
  }
}

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = store.reading;
    return _Page(
      title: 'À lire',
      child: items.isEmpty
          ? const _Empty(Icons.bookmark_border, 'Rien à lire pour l\'instant',
              'Touche « Tap Back » puis « À lire » pour garder un lien/texte et programmer un rappel.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: _card,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(it.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked),
                        color: it.done ? Colors.green : _textSecondary,
                        onPressed: () => store.toggleReading(it.id),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                decoration:
                                    it.done ? TextDecoration.lineThrough : null,
                                color: it.done ? Colors.white38 : Colors.white,
                              ),
                            ),
                            if (it.remindAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('⏰ ${formatStamp(it.remindAt!)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orangeAccent)),
                              ),
                            Text('Ajouté : ${formatStamp(it.createdAt)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white38)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: _textSecondary,
                        onPressed: () {
                          Notifications.cancel(it.notificationId);
                          store.deleteReading(it.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// Fenêtre de commande (Tap Back)
// ============================================================

enum _Mode { choices, note, todo, reading }

class CommandPanel extends StatefulWidget {
  /// Ouvre l'app sur un onglet (0 = Notes, 1 = To-Do, 2 = À lire).
  final void Function(int index) onOpenTab;
  const CommandPanel({super.key, required this.onOpenTab});
  @override
  State<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends State<CommandPanel> {
  _Mode _mode = _Mode.choices;

  final _noteTitle = TextEditingController();
  final _noteBody = TextEditingController();
  final _todoText = TextEditingController();

  // « À lire » : un ou plusieurs champs + choix de rappel.
  final List<TextEditingController> _readControllers = [TextEditingController()];
  String _remindKey = 'none';

  static const _remindOptions = [
    ('none', 'Aucun'),
    ('1h', 'Dans 1 h'),
    ('eve', 'Ce soir 20h'),
    ('tom', 'Demain 9h'),
    ('3d', 'Dans 3 j'),
  ];

  @override
  void dispose() {
    _noteTitle.dispose();
    _noteBody.dispose();
    _todoText.dispose();
    for (final c in _readControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            elevation: 12,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildMode(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMode() {
    switch (_mode) {
      case _Mode.choices:
        return _choices();
      case _Mode.note:
        return _notePanel();
      case _Mode.todo:
        return _todoPanel();
      case _Mode.reading:
        return _readingPanel();
    }
  }

  Widget _choices() {
    return Column(
      key: const ValueKey('choices'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _cmd(Icons.edit_note, 'Note', () => setState(() => _mode = _Mode.note)),
            const SizedBox(width: 8),
            _cmd(Icons.add_task, 'To-Do', () => setState(() => _mode = _Mode.todo)),
            const SizedBox(width: 8),
            _cmd(Icons.bookmark_add_outlined, 'À lire',
                () => setState(() => _mode = _Mode.reading)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _cmdWide(Icons.menu_book, 'Voir les notes', () {
                widget.onOpenTab(0);
                _close();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cmdWide(Icons.checklist, 'Voir To-Do', () {
                widget.onOpenTab(1);
                _close();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cmd(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: _WhiteButton(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: Colors.black),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _cmdWide(IconData icon, String label, VoidCallback onTap) {
    return _WhiteButton(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _head(String title) {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => _mode = _Mode.choices),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F3),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.chevron_left, color: Colors.black),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
      ],
    );
  }

  Widget _notePanel() {
    return Column(
      key: const ValueKey('note'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('Note'),
        const SizedBox(height: 10),
        _field(_noteTitle, 'Titre…', autofocus: true),
        const SizedBox(height: 8),
        _field(_noteBody, 'Écris ta note…', maxLines: 4),
        const SizedBox(height: 10),
        _primary('Enregistrer', () {
          final title = _noteTitle.text.trim();
          final body = _noteBody.text.trim();
          if (title.isEmpty && body.isEmpty) return;
          store.addNote(Note(
            id: _uid(),
            createdAt: DateTime.now(),
            title: title.isEmpty ? 'Note' : title,
            body: body,
          ));
          widget.onOpenTab(0);
          _close();
        }),
      ],
    );
  }

  Widget _todoPanel() {
    return Column(
      key: const ValueKey('todo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('To-Do'),
        const SizedBox(height: 10),
        _field(_todoText, 'Nouvelle tâche…', autofocus: true, maxLines: 2),
        const SizedBox(height: 10),
        _primary('Ajouter', () {
          final text = _todoText.text.trim();
          if (text.isEmpty) return;
          store.addTodo(Todo(id: _uid(), createdAt: DateTime.now(), text: text));
          _close();
        }),
      ],
    );
  }

  Widget _readingPanel() {
    return Column(
      key: const ValueKey('reading'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('À lire plus tard'),
        const SizedBox(height: 8),
        const Text(
          'Garde un lien ou un texte à lire plus tard. Ajoute-en autant que tu veux, et programme un rappel.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < _readControllers.length; i++) ...[
          _field(_readControllers[i],
              i == 0 ? 'Lien ou texte à lire…' : 'Autre élément…',
              autofocus: i == 0),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: _chip('＋ Ajouter',
              () => setState(() => _readControllers.add(TextEditingController()))),
        ),
        const SizedBox(height: 14),
        const Text('⏰ Me le rappeler',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: _remindChips()),
        const SizedBox(height: 14),
        _primary('Enregistrer', _saveReading),
      ],
    );
  }

  List<Widget> _remindChips() {
    return _remindOptions.map((o) {
      final on = _remindKey == o.$1;
      return GestureDetector(
        onTap: () => setState(() => _remindKey = o.$1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF0A0A0C) : Colors.white,
            border: Border.all(
                color: on ? const Color(0xFF0A0A0C) : Colors.black12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(o.$2,
              style: TextStyle(
                  color: on ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );
    }).toList();
  }

  DateTime? _remindDateTime(String key) {
    final now = DateTime.now();
    switch (key) {
      case '1h':
        return now.add(const Duration(hours: 1));
      case 'eve':
        var d = DateTime(now.year, now.month, now.day, 20);
        if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
        return d;
      case 'tom':
        final t = now.add(const Duration(days: 1));
        return DateTime(t.year, t.month, t.day, 9);
      case '3d':
        final t = now.add(const Duration(days: 3));
        return DateTime(t.year, t.month, t.day, 9);
      default:
        return null;
    }
  }

  void _saveReading() {
    final texts = _readControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isEmpty) return;
    final remindAt = _remindDateTime(_remindKey);
    if (remindAt != null) Notifications.requestPermission();
    for (final text in texts) {
      final item = ReadItem(
          id: _uid(), createdAt: DateTime.now(), text: text, remindAt: remindAt);
      store.addReading(item);
      if (remindAt != null) {
        Notifications.schedule(
            id: item.notificationId, body: text, when: remindAt);
      }
    }
    widget.onOpenTab(2);
    _close();
  }

  Widget _chip(String label, VoidCallback onTap) {
    return _WhiteButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(label,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {bool autofocus = false, int maxLines = 1, VoidCallback? onSubmit}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: const Color(0xFFF1F1F4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap) {
    return _WhiteButton(
      onTap: onTap,
      filledBlack: true,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }
}

/// Bouton blanc (ou noir si `filledBlack`) avec effet de pression.
class _WhiteButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool filledBlack;
  final EdgeInsets padding;
  const _WhiteButton({
    required this.child,
    required this.onTap,
    this.filledBlack = false,
    this.padding = const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
  });
  @override
  State<_WhiteButton> createState() => _WhiteButtonState();
}

class _WhiteButtonState extends State<_WhiteButton> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.filledBlack ? const Color(0xFF0A0A0C) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: widget.filledBlack
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.10)),
            boxShadow: widget.filledBlack
                ? null
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
