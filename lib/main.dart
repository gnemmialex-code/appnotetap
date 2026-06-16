// TapBack Note — application Flutter.
// Thème blanc et gris clair, police Montserrat, boutons arrondis avec ombre.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, MethodChannel, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'calendar_sync.dart';
import 'models.dart';
import 'notifications.dart';
import 'onboarding.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  await store.load();
  await calendarSync.init();
  runApp(const TapBackApp());
}

// ── Palette (clair / sombre) ────────────────────────────────────────────────
// `_themeT` est animé de 0 (clair) à 1 (sombre) par _TapBackAppState : toutes
// les couleurs ci-dessous sont interpolées à chaque frame, ce qui rend la
// bascule de thème fluide sur l'ensemble de l'interface.
double _themeT = 0;

Color _mix(int light, int dark) =>
    Color.lerp(Color(light), Color(dark), _themeT)!;

Color get _bg            => _mix(0xFFFFFFFF, 0xFF000000);
Color get _surface       => _mix(0xFFFFFFFF, 0xFF111111);
Color get _surfaceStrong => _mix(0xFFF0F0F5, 0xFF1C1C1C);
Color get _textPrimary   => _mix(0xFF1C1C2E, 0xFFFFFFFF);
Color get _textSecondary => _mix(0xFF888898, 0xFF8E8E93);
Color get _border        => _mix(0xFFE2E2EA, 0xFF2C2C2C);
Color get _textFaint     => _mix(0xFFBBBBCC, 0xFF555555);
Color get _iconFaint     => _mix(0xFFCCCCE0, 0xFF444444);

Color get _onPrimary     => _mix(0xFFFFFFFF, 0xFF000000);

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

bool get _needsOnboarding =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    !store.backTapSetupDone;

class TapBackApp extends StatefulWidget {
  const TapBackApp({super.key});
  @override
  State<TapBackApp> createState() => _TapBackAppState();
}

class _TapBackAppState extends State<TapBackApp>
    with SingleTickerProviderStateMixin {
  // Anime la bascule clair ↔ sombre : chaque frame met à jour `_themeT`
  // et reconstruit l'arbre, donc toutes les couleurs glissent en douceur.
  late final AnimationController _theme = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: store.darkMode ? 1 : 0,
  )..addListener(() => setState(() => _themeT = _theme.value));

  @override
  void initState() {
    super.initState();
    _themeT = store.darkMode ? 1 : 0;
    store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    final target = store.darkMode ? 1.0 : 0.0;
    if (_theme.value != target) {
      _theme.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _themeT > 0.5;
    final textTheme = GoogleFonts.montserratTextTheme(
        (dark ? ThemeData.dark() : ThemeData.light()).textTheme);
    final scheme = dark
        ? ColorScheme.dark(
            surface: _bg,
            onSurface: _textPrimary,
            primary: _textPrimary,
            onPrimary: _onPrimary,
            secondary: _textPrimary,
            onSecondary: _onPrimary,
          )
        : ColorScheme.light(
            surface: _bg,
            onSurface: _textPrimary,
            primary: _textPrimary,
            onPrimary: _onPrimary,
            secondary: _textPrimary,
            onSecondary: _onPrimary,
          );
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: _bg,
      colorScheme: scheme,
      textTheme: textTheme,
      // NavigationBar (barre du bas)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _surfaceStrong,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
              color: sel ? _textPrimary : _textSecondary, size: 27);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? _textPrimary : _textSecondary,
          );
        }),
      ),
      // TabBar (CaptureHub)
      tabBarTheme: TabBarThemeData(
        labelColor: _textPrimary,
        unselectedLabelColor: _textSecondary,
        labelStyle:
            GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          color: _textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: _textPrimary,
        collapsedIconColor: _textSecondary,
        textColor: _textPrimary,
        collapsedTextColor: _textPrimary,
      ),
    );
    return MaterialApp(
      title: 'Shortist',
      debugShowCheckedModeBanner: false,
      theme: base,
      // Dates, sélecteurs (jours, mois…) et boutons système en français.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: _needsOnboarding ? '/onboarding' : '/app',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        // Ouvrir l'app (icône ou bouton « Ouvrir l'application » du panneau
        // système) mène DIRECTEMENT à l'accueil complet, onglet Capture.
        '/app': (_) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final int initialTab; // 0 = Capture, 1 = Agenda, 2 = Carnet, 3 = Réglages
  final int initialSub; // sous-onglet Capture : 0 Notes, 1 To-Do, 2 À lire
  const HomePage({super.key, this.initialTab = 0, this.initialSub = 0});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late int _tab = widget.initialTab;
  late int _captureSub = widget.initialSub;

  static const _ch = MethodChannel('com.gnemmialex.tapbacknote/tapback');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Vérifie le flag caméra au lancement (au cas où l'intent a ouvert l'app).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCameraFlag());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour au premier plan : recharge le store (le panneau système
    // App Intents a pu écrire pendant que l'app était en arrière-plan)
    // et rafraîchit l'Agenda depuis le Calendrier iPhone.
    if (state == AppLifecycleState.resumed) {
      store.load();
      calendarSync.refresh();
      _checkCameraFlag();
    }
  }

  /// Si l'intent "Appareil photo" a ouvert l'app, navigue vers À lire
  /// et ouvre directement le picker caméra.
  Future<void> _checkCameraFlag() async {
    try {
      final pending = await _ch.invokeMethod<bool>('consumeCameraForReading');
      if (pending != true || !mounted) return;
      // Aller sur l'onglet Capture → À lire (index 2).
      setState(() {
        _tab = 0;
        _captureSub = 2;
      });
      // Ouvre le picker caméra après le rendu.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final b64 = await _pickImageSheet(context, forceCamera: true);
        if (b64 == null || !mounted) return;
        _addReadingFromCamera(b64);
      });
    } catch (_) {}
  }

  void _addReadingFromCamera(String b64) {
    final item = ReadItem(
      id: _uid(),
      createdAt: DateTime.now(),
      text: '',
      imageB64: b64,
    );
    store.addReading(item);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: _body(),
          ),
          bottomNavigationBar: _navBar(),
        );
      },
    );
  }

  Widget _body() {
    final screens = [
      CaptureHub(sub: _captureSub),
      const AgendaScreen(),
      const CarnetScreen(),
      const SettingsScreen(),
    ];
    return AnimatedSwitcher(
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
    );
  }

  Widget _navBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed),
              label: 'Capture'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Agenda'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Carnet'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Réglages'),
        ],
      ),
    );
  }
}

// ============================================================
// Widgets partagés
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
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary)),
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
            Icon(icon, size: 44, color: _iconFaint),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    fontSize: 16, color: _textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

BoxDecoration get _card => BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _textPrimary.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

// ============================================================
// Écrans
// ============================================================

class NotesScreen extends StatelessWidget {
  final bool embedded;
  const NotesScreen({super.key, this.embedded = false});

  void _addNoteFromApp(BuildContext context) {
    final title = TextEditingController();
    final body = TextEditingController();
    _showSheet(context, 'Nouvelle note rapide', (setSheet) {
      return [
        _sheetField(title, 'Titre de la note…'),
        const SizedBox(height: 8),
        _sheetField(body, 'Détail (optionnel)…', maxLines: 4),
        const SizedBox(height: 14),
        _sheetPrimary('Ajouter', () {
          if (title.text.trim().isEmpty) return;
          store.addNote(Note(
            id: _uid(),
            createdAt: DateTime.now(),
            title: title.text.trim(),
            body: body.text.trim(),
          ));
          Navigator.of(context).pop();
        }),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = store.notes;

    final banner = Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚡ Notes rapides · Suppression auto après 24h · Rappel toutes les heures',
              style: GoogleFonts.montserrat(
                  fontSize: 11, color: Colors.orange.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );

    final fab = Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'notes_fab',
        backgroundColor: _textPrimary,
        foregroundColor: _onPrimary,
        onPressed: () => _addNoteFromApp(context),
        child: const Icon(Icons.add, size: 28),
      ),
    );

    Widget listContent;
    if (notes.isEmpty) {
      listContent = const _Empty(Icons.mic_none, 'Aucune note rapide',
          'Touche « + » ou « Tap Back » puis Note pour créer une note rapide.');
    } else {
      listContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: notes.length,
        itemBuilder: (context, i) {
          final n = notes[i];
          final deleteAt = n.createdAt.add(const Duration(hours: 24));
          final remaining = deleteAt.difference(DateTime.now());
          final remainingText = remaining.isNegative
              ? 'Expirée'
              : remaining.inHours >= 1
                  ? '${remaining.inHours}h restante${remaining.inHours > 1 ? 's' : ''}'
                  : '${remaining.inMinutes}min';
          final isUrgent = !remaining.isNegative && remaining.inHours < 2;

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
                          style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined, size: 22),
                      color: _textSecondary,
                      tooltip: 'Déplacer vers À lire',
                      onPressed: () {
                        store.moveNoteToReading(n.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Note déplacée vers « À lire »',
                                style: GoogleFonts.montserrat()),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 22),
                      color: _textSecondary,
                      onPressed: () => store.deleteNote(n.id),
                    ),
                  ],
                ),
                if (n.body.isNotEmpty)
                  Text(n.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                          fontSize: 16, color: _textSecondary, height: 1.4)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(formatStamp(n.createdAt),
                          style: GoogleFonts.montserrat(
                              fontSize: 13, color: _textFaint)),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isUrgent ? Colors.red : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 11,
                              color: isUrgent ? Colors.red : Colors.orange),
                          const SizedBox(width: 3),
                          Text(remainingText,
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: isUrgent
                                      ? Colors.red
                                      : Colors.orange.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        banner,
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: listContent),
              fab,
            ],
          ),
        ),
      ],
    );

    return embedded ? body : _Page(title: '📱 Notes', child: body);
  }
}

class TodosScreen extends StatefulWidget {
  final bool embedded;
  const TodosScreen({super.key, this.embedded = false});
  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final all = store.todos;
    final active = all.where((t) => !t.done).toList();
    final done = all.where((t) => t.done).toList()
      ..sort((a, b) =>
          (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));
    final list = _showArchive ? done : active;

    final body = Column(
      children: [
        _header(active.length, done.length),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: list.isEmpty
                    ? _emptyFor(_showArchive)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _showArchive
                            ? _archiveTile(list[i])
                            : _TodoTile(
                                key: ValueKey(list[i].id),
                                todo: list[i],
                                onEdit: () => _editTodo(list[i]),
                              ),
                      ),
              ),
              if (!_showArchive)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'todo_fab',
                    backgroundColor: _textPrimary,
                    foregroundColor: _onPrimary,
                    onPressed: _addTodo,
                    child: const Icon(Icons.add, size: 28),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return widget.embedded ? body : _Page(title: 'To-Do', child: body);
  }

  Widget _header(int activeCount, int doneCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _segmented(activeCount, doneCount),
    );
  }

  void _addTodo() {
    final text = TextEditingController();
    final desc = TextEditingController();
    _showSheet(context, 'Nouvelle tâche', (setSheet) {
      return [
        _sheetField(text, 'Tâche…'),
        const SizedBox(height: 8),
        _sheetField(desc, 'Description (optionnel)…', maxLines: 3),
        const SizedBox(height: 14),
        _sheetPrimary('Ajouter', () {
          if (text.text.trim().isEmpty) return;
          store.addTodo(Todo(
            id: _uid(),
            createdAt: DateTime.now(),
            text: text.text.trim(),
            description: desc.text.trim(),
          ));
          Navigator.of(context).pop();
        }),
      ];
    });
  }

  Widget _segmented(int activeCount, int doneCount) {
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _textPrimary.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Text(label,
                style: GoogleFonts.montserrat(
                    color: selected ? _onPrimary : _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: _surfaceStrong, borderRadius: BorderRadius.circular(14)),
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
          'Les tâches cochées sont conservées ici avec leurs dates.')
      : const _Empty(Icons.checklist, 'Aucune tâche',
          'Touche + pour ajouter ta première tâche.');

  void _editTodo(Todo t) {
    final text = TextEditingController(text: t.text);
    final desc = TextEditingController(text: t.description);
    _showSheet(context, 'Modifier la tâche', (setSheet) {
      return [
        _sheetField(text, 'Tâche…'),
        const SizedBox(height: 8),
        _sheetField(desc, 'Description (optionnel)…', maxLines: 4),
        const SizedBox(height: 14),
        _sheetPrimary('Enregistrer', () {
          store.updateTodo(t.id,
              text: text.text.trim(), description: desc.text.trim());
          Navigator.of(context).pop();
        }),
      ];
    });
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editTodo(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.text,
                      style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: _textSecondary,
                          decoration: TextDecoration.lineThrough)),
                  if (t.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        t.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 14, color: _textSecondary, height: 1.4),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('Créée : ${formatStamp(t.createdAt)}',
                      style: GoogleFonts.montserrat(
                          fontSize: 13, color: _textFaint)),
                  if (t.doneAt != null)
                    Text('Faite : ${formatStamp(t.doneAt!)}',
                        style: GoogleFonts.montserrat(
                            fontSize: 13, color: Colors.green.shade600)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 24),
            color: _textSecondary,
            onPressed: () => store.deleteTodo(t.id),
          ),
        ],
      ),
    );
  }
}

// ─── Tile animée pour les tâches actives ───────────────────────────────────
// Quand l'utilisateur coche la case :
//   1. L'icône vire au vert et rebondit (spring).
//   2. Le fond flashe légèrement en vert.
//   3. La ligne glisse vers la droite et disparaît en fondu.
//   4. La hauteur s'efface (collapse), faisant remonter les items du dessous.
//   5. store.toggleTodo() est appelé : la tâche passe dans « Terminées ».

class _TodoTile extends StatefulWidget {
  final Todo todo;
  final VoidCallback onEdit;
  const _TodoTile({super.key, required this.todo, required this.onEdit});

  @override
  State<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<_TodoTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  // Rebond du check : 1 → 1.35 → 1 sur les 35 premières %
  late final Animation<double> _iconScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.35)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.35, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 17,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
  ]).animate(_ctrl);

  // Flash vert en fond : 0 → 0.12 → 0 sur les 40 premières %
  late final Animation<double> _bgAlpha = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 0.12)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.12, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
  ]).animate(_ctrl);

  // Fondu : 1 → 0 de 35 % à 80 %
  late final Animation<double> _fade =
      Tween<double>(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.80, curve: Curves.easeInCubic)),
  );

  // Glissement vers la droite : de 35 % à 80 %
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: Offset.zero, end: const Offset(0.1, 0)).animate(
    CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.80, curve: Curves.easeIn)),
  );

  // Collapse de la hauteur : 1 → 0 de 72 % à 100 %
  late final Animation<double> _size =
      Tween<double>(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.72, 1.0, curve: Curves.easeInOut)),
  );

  bool _animating = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onCheck() async {
    if (_animating) return;
    _animating = true;
    await _ctrl.forward();
    if (mounted) store.toggleTodo(widget.todo.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.todo;
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.lerp(_surface, Colors.green, _bgAlpha.value),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _textPrimary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _onCheck,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Transform.scale(
                          scale: _iconScale.value,
                          child: Icon(
                            _ctrl.value > 0.01
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 28,
                            color: _ctrl.value > 0.01
                                ? Colors.green
                                : _textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onEdit,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.text,
                              style: GoogleFonts.montserrat(
                                fontSize: 17,
                                color: _textPrimary,
                              ),
                            ),
                            if (t.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  t.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: _textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 24),
                      color: _textSecondary,
                      onPressed: () => store.deleteTodo(t.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReadingScreen extends StatelessWidget {
  final bool embedded;
  const ReadingScreen({super.key, this.embedded = false});

  void _addReadingItem(BuildContext context) {
    final text = TextEditingController();
    DateTime? remindAt;
    String? imageB64;
    _showSheet(context, 'Ajouter à lire', (setSheet) {
      return [
        _sheetField(text, 'Texte ou URL…', maxLines: 3),
        const SizedBox(height: 8),
        _DateTimeRow(
          when: remindAt,
          optional: true,
          onPick: (d) => setSheet(() => remindAt = d),
        ),
        const SizedBox(height: 8),
        Builder(builder: (innerCtx) => PressPop(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: BorderSide(color: _border),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.image_outlined, size: 22),
            label: Text(
              imageB64 == null ? 'Ajouter une image' : 'Image ajoutée ✓',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final b64 = await _pickImageSheet(innerCtx);
              if (b64 == null) return;
              setSheet(() => imageB64 = b64);
            },
          ),
        )),
        const SizedBox(height: 14),
        _sheetPrimary('Ajouter', () {
          if (text.text.trim().isEmpty && imageB64 == null) return;
          final item = ReadItem(
            id: _uid(),
            createdAt: DateTime.now(),
            text: text.text.trim(),
            remindAt: remindAt,
            imageB64: imageB64,
          );
          if (remindAt != null) {
            Notifications.schedule(
              id: item.notificationId,
              body: item.text.isEmpty ? 'Élément à lire' : item.text,
              when: remindAt!,
            );
          }
          store.addReading(item);
          Navigator.of(context).pop();
        }),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = store.reading;

    final fab = Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'reading_fab',
        backgroundColor: _textPrimary,
        foregroundColor: _onPrimary,
        onPressed: () => _addReadingItem(context),
        child: const Icon(Icons.add, size: 28),
      ),
    );

    Widget listContent;
    if (items.isEmpty) {
      listContent = const _Empty(Icons.bookmark_border, 'Rien à lire',
          'Touche « + » ou « Tap Back » puis « À lire » pour garder un lien/texte.');
    } else {
      listContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(
                          it.done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 28),
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
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              decoration:
                                  it.done ? TextDecoration.lineThrough : null,
                              color: it.done ? _textFaint : _textPrimary,
                            ),
                          ),
                          if (it.remindAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('⏰ ${formatStamp(it.remindAt!)}',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      color: Colors.orange.shade700)),
                            ),
                          Text('Ajouté : ${formatStamp(it.createdAt)}',
                              style: GoogleFonts.montserrat(
                                  fontSize: 13, color: _textFaint)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 24),
                      color: _textSecondary,
                      onPressed: () {
                        Notifications.cancel(it.notificationId);
                        store.deleteReading(it.id);
                      },
                    ),
                  ],
                ),
                if (it.imageB64 != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(it.imageB64!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    final body = Stack(
      children: [
        Positioned.fill(child: listContent),
        fab,
      ],
    );

    return embedded ? body : _Page(title: '📚 À lire', child: body);
  }
}

// ============================================================
// Hub Capture : Notes + To-Do + À lire
// ============================================================

class CaptureHub extends StatefulWidget {
  final int sub;
  const CaptureHub({super.key, required this.sub});
  @override
  State<CaptureHub> createState() => _CaptureHubState();
}

class _CaptureHubState extends State<CaptureHub>
    with SingleTickerProviderStateMixin {
  late final TabController _c =
      TabController(length: 3, vsync: this, initialIndex: widget.sub);

  @override
  void didUpdateWidget(CaptureHub old) {
    super.didUpdateWidget(old);
    if (widget.sub != old.sub && widget.sub != _c.index) {
      _c.animateTo(widget.sub);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        TabBar(
          controller: _c,
          tabs: const [
            Tab(text: '📱 Notes'),
            Tab(text: '✅ To-Do'),
            Tab(text: '📚 À lire'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _c,
            // Pas de `const` ici : des enfants const ne sont jamais
            // reconstruits, donc une suppression (corbeille) resterait
            // affichée jusqu'au changement d'onglet.
            children: [
              NotesScreen(embedded: true),
              TodosScreen(embedded: true),
              ReadingScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Agenda
// ============================================================

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  @override
  void initState() {
    super.initState();
    calendarSync.addListener(_onSync);
    calendarSync.refresh();
  }

  @override
  void dispose() {
    calendarSync.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final linked = calendarSync.linked;
    // Une fois connecté, le Calendrier iPhone est la source de vérité ;
    // sinon l'Agenda reste local (web de développement, accès refusé…).
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final allEvents = linked ? calendarSync.events : store.events;
    // On n'affiche que les événements à partir d'aujourd'hui (minuit).
    final events = allEvents
        .where((e) => !e.when.isBefore(todayStart))
        .toList();
    return _Page(
      title: 'Agenda',
      trailing: PressPop(
        child: IconButton(
          icon: Icon(Icons.add, color: _textPrimary, size: 30),
          onPressed: () => _add(context),
        ),
      ),
      child: Column(
        children: [
          if (!calendarSync.available) _webInfoCard(),
          if (calendarSync.available && !linked) _linkCard(),
          if (linked) _syncedBadge(),
          _todayHeader(now),
          Expanded(
            child: events.isEmpty
                ? const _Empty(Icons.event, 'Aucun événement à venir',
                    'Touche « + » pour ajouter un événement à ton agenda.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: events.length,
                    itemBuilder: (context, i) => _eventTile(events[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _todayHeader(DateTime now) {
    const dayNames = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    const monthNames = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    final label =
        '${dayNames[now.weekday - 1]} ${now.day} ${monthNames[now.month]} ${now.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "Aujourd'hui",
              style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _onPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _eventTile(CalEvent ev) {
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
                    style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
                Text(_monthShort(ev.when.month),
                    style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: _textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Toucher l'événement = le modifier (répercuté dans le
              // Calendrier iPhone quand l'Agenda est connecté).
              onTap: ev.editable ? () => _edit(ev) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.title,
                      style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                  Text(
                      '🕒 $hm${ev.note.isNotEmpty ? ' · ${ev.note}' : ''}',
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: _textSecondary)),
                  if (ev.calendarName.isNotEmpty)
                    Text('📅 ${ev.calendarName}',
                        style: GoogleFonts.montserrat(
                            fontSize: 11, color: _textFaint)),
                ],
              ),
            ),
          ),
          if (ev.editable)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 24),
              color: _textSecondary,
              onPressed: () => _delete(ev),
            ),
        ],
      ),
    );
  }

  /// Sur le web de développement : la synchro n'existe que sur iPhone.
  Widget _webInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          Icon(Icons.phone_iphone, color: _textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sur iPhone, l\'Agenda se connecte au vrai Calendrier (autorisation d\'afficher, ajouter, modifier et supprimer). Ici sur le web, il fonctionne en local.',
              style: GoogleFonts.montserrat(
                  fontSize: 12, color: _textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte d'invitation à connecter l'Agenda au Calendrier iPhone.
  Widget _linkCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sync, color: _textPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Synchroniser avec le Calendrier',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Connecte ton Agenda au Calendrier de l\'iPhone : chaque ajout ou suppression est répercuté des deux côtés, en permanence.',
            style: GoogleFonts.montserrat(
                fontSize: 13, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          PressPop(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _textPrimary,
                foregroundColor: _onPrimary,
                elevation: 0,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.event_available, size: 22),
              label: Text(
                  calendarSync.busy ? 'Connexion…' : 'Connecter mon Agenda',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: calendarSync.busy ? null : _link,
            ),
          ),
        ],
      ),
    );
  }

  /// Bandeau « connecté » + choix du calendrier de destination
  /// (iCloud, Google, Outlook… selon les comptes de l'iPhone).
  Widget _syncedBadge() {
    final target = calendarSync.targetCalendarName.isEmpty
        ? 'Calendrier par défaut'
        : calendarSync.targetCalendarName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Synchronisé · ajouts dans : $target',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                    fontSize: 12, color: _textSecondary)),
          ),
          PressPop(
            child: GestureDetector(
              onTap: _pickCalendar,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _surfaceStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Changer',
                    style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Feuille de choix du calendrier de destination des nouveaux événements.
  Future<void> _pickCalendar() async {
    final cals = await calendarSync.calendars();
    if (!mounted) return;
    _showSheet(context, 'Créer mes événements dans…', (setSheet) {
      Widget option(
          {required String title,
          required String subtitle,
          required bool selected,
          required VoidCallback onTap}) {
        return PressPop(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? _textPrimary : _surfaceStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: selected ? _onPrimary : _textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    selected ? _onPrimary : _textPrimary)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: selected
                                      ? _onPrimary.withValues(alpha: 0.7)
                                      : _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return [
        Text(
          'Tes événements restent visibles tous calendriers confondus ; ce choix fixe où sont créés les nouveaux (iCloud, Google, Outlook…).',
          style: GoogleFonts.montserrat(
              fontSize: 12, color: _textSecondary, height: 1.5),
        ),
        const SizedBox(height: 12),
        option(
          title: 'Calendrier par défaut de l\'iPhone',
          subtitle: '',
          selected: calendarSync.targetCalendarId == null,
          onTap: () {
            calendarSync.setTarget(null);
            Navigator.of(context).pop();
          },
        ),
        ...cals.map((c) => option(
              title: c.title,
              subtitle: c.source,
              selected: calendarSync.targetCalendarId == c.id,
              onTap: () {
                calendarSync.setTarget(c);
                Navigator.of(context).pop();
              },
            )),
      ];
    });
  }

  Future<void> _link() async {
    final ok = await calendarSync.link();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Accès refusé. Autorise le Calendrier dans Réglages iOS → Confidentialité → Calendriers → Shortist (Accès complet).',
            style: GoogleFonts.montserrat()),
      ),
    );
  }

  Future<void> _delete(CalEvent ev) async {
    if (calendarSync.linked && ev.deviceId != null) {
      final ok = await calendarSync.delete(ev);
      if (!ok && mounted) _syncError('Suppression impossible dans le Calendrier.');
    } else {
      store.deleteEvent(ev.id);
    }
  }

  void _syncError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.montserrat())),
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
        _sheetPrimary('Ajouter à l\'agenda', () async {
          if (title.text.trim().isEmpty) return;
          Navigator.of(context).pop();
          if (calendarSync.linked) {
            // Créé directement dans le Calendrier iPhone.
            final ok = await calendarSync.add(
                title: title.text.trim(),
                when: when,
                note: note.text.trim());
            if (!ok && mounted) {
              _syncError('Ajout impossible dans le Calendrier.');
            }
          } else {
            store.addEvent(CalEvent(
              id: _uid(),
              title: title.text.trim(),
              when: when,
              note: note.text.trim(),
            ));
          }
        }),
      ];
    });
  }

  /// Modification d'un événement — répercutée dans le Calendrier iPhone
  /// quand l'Agenda est connecté.
  void _edit(CalEvent ev) {
    final title = TextEditingController(text: ev.title);
    final note = TextEditingController(text: ev.note);
    DateTime when = ev.when;
    _showSheet(context, 'Modifier l\'événement', (setSheet) {
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
        _sheetPrimary('Enregistrer', () async {
          if (title.text.trim().isEmpty) return;
          Navigator.of(context).pop();
          if (calendarSync.linked && ev.deviceId != null) {
            final ok = await calendarSync.update(ev,
                title: title.text.trim(),
                when: when,
                note: note.text.trim());
            if (!ok && mounted) {
              _syncError('Modification impossible dans le Calendrier.');
            }
          } else {
            store.updateEvent(ev.id,
                title: title.text.trim(), when: when, note: note.text.trim());
          }
        }),
      ];
    });
  }
}

// ============================================================
// Carnet
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
          icon: Icon(Icons.add, color: _textPrimary, size: 30),
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
                                style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 24),
                            color: _textSecondary,
                            onPressed: () => store.deleteCarnet(f.id),
                          ),
                        ],
                      ),
                      if (f.note.isNotEmpty)
                        Text(f.note,
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: _textSecondary,
                                height: 1.4)),
                      if (f.when != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('🕒 ${formatStamp(f.when!)}',
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: _textFaint)),
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
        Builder(builder: (innerCtx) => PressPop(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: BorderSide(color: _border),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.image_outlined, size: 22),
            label: Text(
                imageB64 == null ? 'Ajouter une image' : 'Image ajoutée ✓',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            onPressed: () async {
              final b64 = await _pickImageSheet(innerCtx);
              if (b64 == null) return;
              setSheet(() => imageB64 = b64);
            },
          ),
        )),
        const SizedBox(height: 14),
        _sheetPrimary('Enregistrer la fiche', () {
          if (title.text.trim().isEmpty && note.text.trim().isEmpty) return;
          store.addCarnet(CarnetEntry(
            id: _uid(),
            createdAt: DateTime.now(),
            title:
                title.text.trim().isEmpty ? 'Fiche' : title.text.trim(),
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

// ============================================================
// Réglages
// ============================================================

const _legalDocs = <(String, String)>[
  ('Conditions générales d\'utilisation (CGU)',
      'Texte des CGU à compléter avant publication. En utilisant TapBack Note, l\'utilisateur accepte ces conditions.'),
  ('Politique de confidentialité',
      'Décrit les données collectées (profil, contenu local), leur usage et les droits de l\'utilisateur. OBLIGATOIRE pour l\'App Store.'),
  ('Mentions légales',
      'Éditeur de l\'app, contact, hébergeur. À compléter.'),
  ('Contrat de licence (EULA Apple)',
      'Par défaut, Apple applique son EULA standard. Tu peux le remplacer par le tien.'),
  ('Règles de l\'App Store',
      'L\'app respecte les Directives de l\'App Store : paiements via achats intégrés, confidentialité, contenu autorisé, etc.'),
  ('Gestion des données / Supprimer mon compte',
      'Apple impose la suppression de compte si l\'app permet d\'en créer un, avec effacement des données.'),
  ('Licences open-source',
      'Liste des bibliothèques tierces et de leurs licences.'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name =
      TextEditingController(text: store.profileName);
  late final TextEditingController _email =
      TextEditingController(text: store.profileEmail);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await store.saveProfile(avatarB64: base64Encode(bytes));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        (store.profileName.trim().isNotEmpty ? store.profileName.trim()[0] : '?')
            .toUpperCase();
    return _Page(
      title: 'Réglages',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // Carte profil
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card,
            child: Column(
              children: [
                Center(
                  child: PressPop(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          ClipOval(
                            child: store.profileAvatarB64 != null
                                ? Image.memory(
                                    base64Decode(store.profileAvatarB64!),
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover)
                                : Container(
                                    width: 84,
                                    height: 84,
                                    color: _surfaceStrong,
                                    alignment: Alignment.center,
                                    child: Text(initial,
                                        style: GoogleFonts.montserrat(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            color: _textPrimary)),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: _textPrimary,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.edit,
                                  size: 15, color: _onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _settingsField(_name, 'Prénom / pseudo'),
                const SizedBox(height: 8),
                _settingsField(_email, 'E-mail',
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                PressPop(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _textPrimary,
                      foregroundColor: _onPrimary,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      await store.saveProfile(
                          name: _name.text.trim(),
                          email: _email.text.trim());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profil enregistré ✓',
                              style:
                                  GoogleFonts.montserrat(color: _onPrimary)),
                          backgroundColor: _textPrimary,
                        ),
                      );
                    },
                    child: Text('Enregistrer',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '📧 Dans la vraie app, l\'e-mail sera relié à ta connexion (Sign in with Apple).',
                  style: GoogleFonts.montserrat(
                      fontSize: 11, color: _textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Apparence : bascule clair / sombre (transition animée).
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Apparence',
                style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.5)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: _card,
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    store.darkMode ? Icons.dark_mode : Icons.light_mode,
                    key: ValueKey(store.darkMode),
                    color: _textPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Mode sombre',
                      style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                ),
                Switch.adaptive(
                  value: store.darkMode,
                  onChanged: (v) => store.setDarkMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Mettre en place — collapsible, ouvre le guide vidéo
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Configuration',
                style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.5)),
          ),
          Container(
            decoration: _card,
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.settings_remote_outlined,
                    color: _textSecondary, size: 22),
                title: Text('Mettre en place',
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                subtitle: Text('Guide de configuration du double-tap',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, color: _textSecondary)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SetupGuideScreen()),
                        ),
                        icon:
                            const Icon(Icons.play_circle_outline, size: 18),
                        label: Text('Revoir la configuration',
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _textPrimary,
                          foregroundColor: _onPrimary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // ── Widgets Home Screen ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Widgets',
                style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.5)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.widgets_outlined, color: _textPrimary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Widgets écran d\'accueil',
                          style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajoute To-Do, Notes, À lire ou Carnet en widget sur ton écran d\'accueil pour accéder rapidement à tes données.',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, color: _textSecondary, height: 1.5),
                ),
                const SizedBox(height: 12),
                PressPop(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _textPrimary,
                      foregroundColor: _onPrimary,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.add_to_home_screen, size: 20),
                    label: Text('Aperçu & ajouter un widget',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    onPressed: () => _showWidgetPreview(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Informations & documents',
                style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.5)),
          ),
          ..._legalDocs.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _card,
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(d.$1,
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.$2,
                          style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: _textSecondary,
                              height: 1.5)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
          Center(
            child: Text('Shortist — v1.0.0',
                style: GoogleFonts.montserrat(
                    fontSize: 11, color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showWidgetPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => const _WidgetPreviewSheet(),
    );
  }

  Widget _settingsField(TextEditingController c, String hint,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: GoogleFonts.montserrat(color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: _textSecondary),
        filled: true,
        fillColor: _surfaceStrong,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ============================================================
// Helpers partagés feuilles d'ajout (Agenda / Carnet)
// ============================================================

String _monthShort(int m) {
  const names = [
    '', 'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sept', 'oct', 'nov', 'déc'
  ];
  return names[m];
}

/// Affiche une action sheet iOS pour choisir la source d'une image,
/// puis retourne le contenu encodé en base64 (ou null si annulé).
/// [forceCamera] : passe directement à l'appareil photo sans action sheet.
Future<String?> _pickImageSheet(BuildContext context,
    {bool forceCamera = false}) async {
  String? source;
  if (forceCamera) {
    source = 'camera';
  } else {
    source = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Ajouter une image',
            style: GoogleFonts.montserrat(fontSize: 14)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('camera'),
            child: Text('📷  Prendre une photo',
                style: GoogleFonts.montserrat()),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('gallery'),
            child: Text('🖼️  Photos',
                style: GoogleFonts.montserrat()),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('files'),
            child: Text('📂  Fichiers',
                style: GoogleFonts.montserrat()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text('Annuler', style: GoogleFonts.montserrat()),
        ),
      ),
    );
  }

  if (source == null) return null;
  if (!context.mounted) return null;

  try {
    if (source == 'files') {
      // Ouvre l'app Fichiers iOS via file_picker.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.first;
      final bytes =
          f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) return null;
      return base64Encode(bytes);
    } else {
      final imageSource =
          source == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final picked = await ImagePicker().pickImage(
        source: imageSource,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return base64Encode(bytes);
    }
  } catch (_) {
    return null;
  }
}

void _showSheet(BuildContext context, String title,
    List<Widget> Function(void Function(VoidCallback)) body) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 22),
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text(title,
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 12),
            ...body(setSheet),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetField(TextEditingController c, String hint,
    {int maxLines = 1}) {
  return TextField(
    controller: c,
    maxLines: maxLines,
    style: GoogleFonts.montserrat(color: _textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.montserrat(color: _textSecondary),
      filled: true,
      fillColor: _surfaceStrong,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        backgroundColor: _textPrimary,
        foregroundColor: _onPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(58),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Text(label,
          style:
              GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16)),
    ),
  );
}

class _DateTimeRow extends StatelessWidget {
  final DateTime? when;
  final bool optional;
  final ValueChanged<DateTime> onPick;
  const _DateTimeRow(
      {required this.when,
      required this.onPick,
      this.optional = false});

  @override
  Widget build(BuildContext context) {
    final label = when == null
        ? (optional ? 'Date & heure (optionnel)' : 'Choisir date & heure')
        : '${when!.day}/${when!.month}/${when!.year} à '
            '${when!.hour.toString().padLeft(2, '0')}:${when!.minute.toString().padLeft(2, '0')}';
    return PressPop(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: BorderSide(color: _border),
          minimumSize: const Size.fromHeight(54),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.schedule, size: 22),
        label: Text(label,
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500, fontSize: 15)),
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            // Sélecteur en français (jours, mois, format JJ/MM/AAAA).
            locale: const Locale('fr'),
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
// Composants d'interaction
// ============================================================

/// Effet « pop » léger à l'appui (scale).
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
      onPointerDown: (_) => _set(0.93),
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

// ============================================================
// Aperçu widgets écran d'accueil (Réglages)
// ============================================================

class _WidgetPreviewSheet extends StatefulWidget {
  const _WidgetPreviewSheet();
  @override
  State<_WidgetPreviewSheet> createState() => _WidgetPreviewSheetState();
}

class _WidgetPreviewSheetState extends State<_WidgetPreviewSheet> {
  int _selected = 0; // 0=To-Do, 1=Notes, 2=À lire, 3=Carnet

  static const _labels = ['✅ To-Do', '📱 Notes', '📚 À lire', '📔 Carnet'];
  static const _icons = [
    Icons.checklist,
    Icons.mic_none,
    Icons.bookmark_border,
    Icons.menu_book_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          children: [
            // Poignée
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text('Widgets écran d\'accueil',
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Choisis un widget à ajouter sur ton écran d\'accueil.',
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: _textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Sélecteur de type
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(4, (i) {
                  final sel = i == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? _textPrimary : _surfaceStrong,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(_icons[i],
                              size: 16,
                              color: sel ? _onPrimary : _textSecondary),
                          const SizedBox(width: 6),
                          Text(_labels[i],
                              style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? _onPrimary : _textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Aperçu du widget
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    _WidgetMockup(type: _selected),
                    const SizedBox(height: 20),
                    // Instructions d'ajout
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surfaceStrong,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comment ajouter ce widget',
                              style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary)),
                          const SizedBox(height: 8),
                          _step('1', 'Appuie longuement sur l\'écran d\'accueil iOS.'),
                          _step('2', 'Appuie sur le bouton « + » en haut à gauche.'),
                          _step('3', 'Recherche « Shortist » dans la liste.'),
                          _step('4', 'Choisis la taille souhaitée puis appuie sur « Ajouter le widget ».'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _textPrimary, shape: BoxShape.circle),
            child: Text(num,
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _onPrimary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.montserrat(
                    fontSize: 13, color: _textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Aperçu stylisé d'un widget (simule un widget iOS 2×2 avec les vraies données).
class _WidgetMockup extends StatelessWidget {
  final int type; // 0=To-Do, 1=Notes, 2=À lire, 3=Carnet
  const _WidgetMockup({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _textPrimary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case 0:
        return _TodoPreview();
      case 1:
        return _NotesPreview();
      case 2:
        return _ReadingPreview();
      default:
        return _CarnetPreview();
    }
  }
}

class _TodoPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = store.todos.where((t) => !t.done).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.checklist, size: 16),
          const SizedBox(width: 6),
          Text('To-Do',
              style: GoogleFonts.montserrat(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        const Divider(height: 12),
        if (items.isEmpty)
          Text('Aucune tâche à faire',
              style: GoogleFonts.montserrat(
                  fontSize: 12, color: _textFaint))
        else
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.radio_button_unchecked,
                      size: 14, color: _textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 13, color: _textPrimary)),
                  ),
                ]),
              )),
      ],
    );
  }
}

class _NotesPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = store.notes.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.mic_none, size: 16),
          const SizedBox(width: 6),
          Text('Notes',
              style: GoogleFonts.montserrat(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        const Divider(height: 12),
        if (items.isEmpty)
          Text('Aucune note rapide',
              style: GoogleFonts.montserrat(
                  fontSize: 12, color: _textFaint))
        else
          ...items.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                    if (n.body.isNotEmpty)
                      Text(n.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                              fontSize: 11, color: _textSecondary)),
                  ],
                ),
              )),
      ],
    );
  }
}

class _ReadingPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items =
        store.reading.where((r) => !r.done).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.bookmark_border, size: 16),
          const SizedBox(width: 6),
          Text('À lire',
              style: GoogleFonts.montserrat(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        const Divider(height: 12),
        if (items.isEmpty)
          Text('Aucun élément à lire',
              style: GoogleFonts.montserrat(
                  fontSize: 12, color: _textFaint))
        else
          ...items.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.bookmark_border,
                      size: 14, color: _textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        r.text.isEmpty ? '(image)' : r.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 13, color: _textPrimary)),
                  ),
                ]),
              )),
      ],
    );
  }
}

class _CarnetPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = store.carnet.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.menu_book_outlined, size: 16),
          const SizedBox(width: 6),
          Text('Carnet',
              style: GoogleFonts.montserrat(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        const Divider(height: 12),
        if (items.isEmpty)
          Text('Carnet vide',
              style: GoogleFonts.montserrat(
                  fontSize: 12, color: _textFaint))
        else
          ...items.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                    if (f.note.isNotEmpty)
                      Text(f.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                              fontSize: 11, color: _textSecondary)),
                  ],
                ),
              )),
      ],
    );
  }
}

// ============================================================
// Guide « Mettre en place » (Réglages)
// ============================================================

/// Carrousel d'images du guide d'installation. Dépose tes captures dans
/// `assets/setup/` (etape_1.png, etape_2.png, …) : elles s'affichent ici
/// dans l'ordre alphabétique des noms de fichiers — rien d'autre à coder.
class _SetupGuideCard extends StatefulWidget {
  const _SetupGuideCard();
  @override
  State<_SetupGuideCard> createState() => _SetupGuideCardState();
}

class _SetupGuideCardState extends State<_SetupGuideCard> {
  final PageController _pages = PageController();
  List<String> _images = const [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final imgs = manifest
        .listAssets()
        .where((a) =>
            a.startsWith('assets/setup/') &&
            RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(a))
        .toList()
      ..sort();
    if (mounted) setState(() => _images = imgs);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: _textPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Comment installer le raccourci',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fais défiler les étapes pour configurer la fenêtre rapide sur ton iPhone.',
            style: GoogleFonts.montserrat(
                fontSize: 13, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          if (_images.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surfaceStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Aucune image pour l\'instant.\n\nDépose tes captures dans assets/setup/ (etape_1.png, etape_2.png, …) : elles apparaîtront ici dans l\'ordre.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    fontSize: 12, color: _textSecondary, height: 1.6),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 420,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => Container(
                    color: _surfaceStrong,
                    child: Image.asset(_images[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page ? _textPrimary : _border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('Étape ${_page + 1} sur ${_images.length}',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, color: _textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}
