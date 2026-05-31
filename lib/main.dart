// TapBack Note — application Flutter (notes, to-dos, recherche rapide).
//
// Concept : un bouton « Tap Back » ouvre une fenêtre de commande en haut de
// l'écran avec 4 actions (Note, To-Do, Rechercher, Voir les notes), chacune
// s'ouvrant en place. Persistance locale via shared_preferences.
//
// NB : sur iOS, la police par défaut est San Francisco (police système).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
const _surfaceStrong = Color(0x1FFFFFFF);
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
          const AgendaScreen(),
          const CarnetScreen(),
        ];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: screens[_tab],
              ),
            ),
          ),
          floatingActionButton: PressPop(
            child: FloatingActionButton.extended(
              onPressed: _openCommand,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.bolt),
              label: const Text('Tap Back',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: const Color(0xFF111114),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.mic_none), label: 'Notes'),
              NavigationDestination(icon: Icon(Icons.checklist), label: 'To-Do'),
              NavigationDestination(
                  icon: Icon(Icons.bookmark_border), label: 'À lire'),
              NavigationDestination(
                  icon: Icon(Icons.event), label: 'Agenda'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book), label: 'Carnet'),
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
  final Widget? trailing;
  const _Page({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w700)),
              ),
              ?trailing,
            ],
          ),
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
// Agenda (événements locaux)
// ============================================================

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = store.events; // déjà triés par date (store.addEvent)
    return _Page(
      title: 'Agenda',
      trailing: PressPop(
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _add(context),
        ),
      ),
      child: events.isEmpty
          ? const _Empty(Icons.event, 'Aucun événement',
              'Touche « + » pour ajouter un événement à ton agenda.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final ev = events[i];
                final hm =
                    '${ev.when.hour.toString().padLeft(2, '0')}:${ev.when.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: _card,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                            color: _surfaceStrong,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text('${ev.when.day}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700)),
                            Text(_monthShort(ev.when.month),
                                style: const TextStyle(
                                    fontSize: 11, color: _textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ev.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('🕒 $hm${ev.note.isNotEmpty ? ' · ${ev.note}' : ''}',
                                style: const TextStyle(
                                    fontSize: 13, color: _textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: _textSecondary,
                        onPressed: () => store.deleteEvent(ev.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _add(BuildContext context) {
    final title = TextEditingController();
    final note = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    _showSheet(context, 'Nouvel événement', (setSheet) {
      return [
        _sheetField(title, 'Titre de l\'événement…'),
        const SizedBox(height: 8),
        _sheetField(note, 'Lieu / note (optionnel)…'),
        const SizedBox(height: 8),
        _DateTimeRow(
          when: when,
          onPick: (d) => setSheet(() => when = d),
        ),
        const SizedBox(height: 14),
        _sheetPrimary('Ajouter à l\'agenda', () {
          if (title.text.trim().isEmpty) return;
          store.addEvent(CalEvent(
            id: _uid(),
            title: title.text.trim(),
            when: when,
            note: note.text.trim(),
          ));
          Navigator.of(context).pop();
        }),
      ];
    });
  }
}

// ============================================================
// Carnet (notes détaillées : titre, note, date/heure, image)
// ============================================================

class CarnetScreen extends StatelessWidget {
  const CarnetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = store.carnet;
    return _Page(
      title: 'Carnet',
      trailing: PressPop(
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _add(context),
        ),
      ),
      child: items.isEmpty
          ? const _Empty(Icons.menu_book, 'Carnet vide',
              'Touche « + » pour créer une fiche : titre, note, date, heure, image.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final f = items[i];
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
                            child: Text(f.title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: _textSecondary,
                            onPressed: () => store.deleteCarnet(f.id),
                          ),
                        ],
                      ),
                      if (f.note.isNotEmpty)
                        Text(f.note,
                            style: const TextStyle(color: _textSecondary)),
                      if (f.when != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('🕒 ${formatStamp(f.when!)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white38)),
                        ),
                      if (f.imageB64 != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(f.imageB64!),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _add(BuildContext context) {
    final title = TextEditingController();
    final note = TextEditingController();
    DateTime? when;
    String? imageB64;
    _showSheet(context, 'Nouvelle fiche', (setSheet) {
      return [
        _sheetField(title, 'Titre…'),
        const SizedBox(height: 8),
        _sheetField(note, 'Note détaillée…', maxLines: 4),
        const SizedBox(height: 8),
        _DateTimeRow(
          when: when,
          optional: true,
          onPick: (d) => setSheet(() => when = d),
        ),
        const SizedBox(height: 8),
        PressPop(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.image_outlined),
            label: Text(imageB64 == null ? 'Ajouter une image' : 'Image ajoutée ✓'),
            onPressed: () async {
              final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              setSheet(() => imageB64 = base64Encode(bytes));
            },
          ),
        ),
        const SizedBox(height: 14),
        _sheetPrimary('Enregistrer la fiche', () {
          if (title.text.trim().isEmpty && note.text.trim().isEmpty) return;
          store.addCarnet(CarnetEntry(
            id: _uid(),
            createdAt: DateTime.now(),
            title: title.text.trim().isEmpty ? 'Fiche' : title.text.trim(),
            note: note.text.trim(),
            when: when,
            imageB64: imageB64,
          ));
          Navigator.of(context).pop();
        }),
      ];
    });
  }
}

// --- Helpers partagés des feuilles d'ajout (Agenda / Carnet) ---

String _monthShort(int m) {
  const names = ['', 'janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil',
    'août', 'sept', 'oct', 'nov', 'déc'];
  return names[m];
}

void _showSheet(BuildContext context, String title,
    List<Widget> Function(void Function(VoidCallback)) body) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15151A),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          left: 18, right: 18, top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 22),
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38, height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...body(setSheet),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetField(TextEditingController c, String hint, {int maxLines = 1}) {
  return TextField(
    controller: c,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Widget _sheetPrimary(String label, VoidCallback onTap) {
  return PressPop(
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

/// Ligne "choisir date + heure" utilisée dans les feuilles d'ajout.
class _DateTimeRow extends StatelessWidget {
  final DateTime? when;
  final bool optional;
  final ValueChanged<DateTime> onPick;
  const _DateTimeRow({required this.when, required this.onPick, this.optional = false});

  @override
  Widget build(BuildContext context) {
    final label = when == null
        ? (optional ? 'Date & heure (optionnel)' : 'Choisir date & heure')
        : '${when!.day}/${when!.month}/${when!.year} à '
            '${when!.hour.toString().padLeft(2, '0')}:${when!.minute.toString().padLeft(2, '0')}';
    return PressPop(
      child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
      icon: const Icon(Icons.schedule),
      label: Text(label),
      onPressed: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: when ?? now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 365 * 3)),
        );
        if (d == null || !context.mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(when ?? now),
        );
        if (t == null) return;
        onPick(DateTime(d.year, d.month, d.day, t.hour, t.minute));
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
  String _remindKey = ''; // '' = aucun rappel (par défaut)
  DateTime? _customDateTime;

  static const _remindOptions = [
    ('1h', 'Dans 1 h'),
    ('eve', 'Ce soir 20h'),
    ('tom', 'Demain 9h'),
    ('3d', 'Dans 3 j'),
  ];

  String _two(int n) => n.toString().padLeft(2, '0');

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
    Widget chip(String key, String label, VoidCallback onTap) {
      final on = _remindKey == key;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF0A0A0C) : Colors.white,
            border: Border.all(
                color: on ? const Color(0xFF0A0A0C) : Colors.black12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );
    }

    final widgets = _remindOptions
        .map((o) => chip(o.$1, o.$2, () => setState(() => _remindKey = o.$1)))
        .toList();
    final customLabel = _customDateTime == null
        ? '🗓️ Personnaliser'
        : '🗓️ ${_customDateTime!.day}/${_customDateTime!.month} à ${_two(_customDateTime!.hour)}:${_two(_customDateTime!.minute)}';
    widgets.add(chip('custom', customLabel, _pickCustom));
    return widgets;
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _customDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _remindKey = 'custom';
    });
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
      case 'custom':
        return _customDateTime;
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

/// Enveloppe n'importe quel bouton/élément tappable d'un effet « pop »
/// (léger rétrécissement) à l'appui, sans intercepter le geste du child.
class PressPop extends StatefulWidget {
  final Widget child;
  const PressPop({super.key, required this.child});
  @override
  State<PressPop> createState() => _PressPopState();
}

class _PressPopState extends State<PressPop> {
  double _scale = 1;
  void _set(double v) => setState(() => _scale = v);
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(0.9),
      onPointerUp: (_) => _set(1),
      onPointerCancel: (_) => _set(1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
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
