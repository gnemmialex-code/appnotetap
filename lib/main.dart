// TapBack Note — application Flutter.
// Thème blanc et gris clair, police Montserrat, boutons arrondis avec ombre.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'bridge.dart';
import 'models.dart';
import 'notifications.dart';
import 'onboarding.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  await store.load();
  initTapBackChannel();
  runApp(const TapBackApp());
}

// ── Palette ─────────────────────────────────────────────────────────────────
const _bg            = Color(0xFFF5F5FA);
const _surface       = Color(0xFFFFFFFF);
const _surfaceStrong = Color(0xFFEEEEF6);
const _textPrimary   = Color(0xFF1C1C2E);
const _textSecondary = Color(0xFF888898);
const _border        = Color(0xFFEAEAF2);

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

class TapBackApp extends StatelessWidget {
  const TapBackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme =
        GoogleFonts.montserratTextTheme(ThemeData.light().textTheme);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.light(
        surface: _bg,
        primary: _textPrimary,
        onPrimary: Colors.white,
        secondary: _textPrimary,
        onSecondary: Colors.white,
      ),
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
              color: sel ? _textPrimary : _textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return GoogleFonts.montserrat(
            fontSize: 11,
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
            GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          color: _textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
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
      initialRoute: _needsOnboarding ? '/onboarding' : '/app',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        // L'écran racine est la petite fenêtre rapide : l'accueil complet
        // (HomePage) n'est accessible que via le bouton flèche du panneau.
        '/app': (_) => const PanelScreen(),
      },
    );
  }
}

// ============================================================
// Écran racine : la petite fenêtre rapide, seule visible.
// Le reste de l'écran est neutre (sombre) — l'accueil complet de
// l'app ne s'ouvre que via le bouton flèche du panneau.
// ============================================================

class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});
  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen>
    with WidgetsBindingObserver {
  // Changer la clé recrée le panneau (retour au menu de choix).
  int _panelGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tapBackTrigger.addListener(_onTapBack);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tapBackTrigger.removeListener(_onTapBack);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour au premier plan, recharge le store : le panneau système
    // (App Intents) a pu ajouter des notes/tâches pendant que l'app
    // était en arrière-plan.
    if (state == AppLifecycleState.resumed) store.load();
  }

  void _onTapBack() {
    if (!mounted) return;
    // Si l'accueil de l'app (ou autre) est ouvert, on revient au panneau,
    // et on remet le panneau sur l'écran de choix.
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _panelGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // iOS ne permet pas de voir le vrai écran d'accueil derrière
              // une app. Si l'utilisateur a fourni une capture de SON écran
              // d'accueil (Réglages), on l'affiche : rendu identique à de la
              // transparence. Sinon, accueil simulé par défaut.
              if (store.panelWallpaperB64 != null)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      base64Decode(store.panelWallpaperB64!),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                    // Léger voile pour faire ressortir la fenêtre blanche.
                    Container(color: Colors.black.withValues(alpha: 0.22)),
                  ],
                )
              else
                const _FakeHomeBackground(),
              CommandPanel(key: ValueKey(_panelGeneration)),
            ],
          );
        },
      ),
    );
  }
}

/// Faux écran d'accueil iPhone : fond d'écran dégradé, grille d'icônes
/// et dock, le tout flouté + voile sombre. Purement décoratif et fixe.
class _FakeHomeBackground extends StatelessWidget {
  const _FakeHomeBackground();

  static const _apps = <(IconData, Color)>[
    (Icons.phone, Color(0xFF34C759)),
    (Icons.chat_bubble, Color(0xFF30B0C7)),
    (Icons.camera_alt, Color(0xFF8E8E93)),
    (Icons.photo, Color(0xFFFF9F0A)),
    (Icons.map, Color(0xFF32ADE6)),
    (Icons.music_note, Color(0xFFFF2D55)),
    (Icons.mail, Color(0xFF007AFF)),
    (Icons.cloud, Color(0xFF5AC8FA)),
    (Icons.calendar_today, Color(0xFFFF3B30)),
    (Icons.alarm, Color(0xFF1C1C1E)),
    (Icons.settings, Color(0xFF636366)),
    (Icons.account_balance_wallet, Color(0xFF0A0A0A)),
    (Icons.tv, Color(0xFF2C2C2E)),
    (Icons.fitness_center, Color(0xFFFF375F)),
    (Icons.podcasts, Color(0xFFBF5AF2)),
    (Icons.newspaper, Color(0xFFFF453A)),
    (Icons.calculate, Color(0xFFFF9500)),
    (Icons.mic, Color(0xFF5856D6)),
    (Icons.book, Color(0xFFFF9F0A)),
    (Icons.videocam, Color(0xFF34C759)),
  ];

  Widget _icon((IconData, Color) app, {double size = 54, bool label = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [app.$2.withValues(alpha: 0.95), app.$2],
            ),
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Icon(app.$1, color: Colors.white, size: size * 0.5),
        ),
        if (label) ...[
          const SizedBox(height: 7),
          Container(
            width: 34,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2A6B),
                  Color(0xFF4A3A8C),
                  Color(0xFF1A4A7A),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int row = 0; row < 5; row++)
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                for (int col = 0; col < 4; col++)
                                  _icon(_apps[row * 4 + col]),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Dock
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _icon((Icons.phone, const Color(0xFF34C759)),
                            label: false),
                        _icon((Icons.public, const Color(0xFF007AFF)),
                            label: false),
                        _icon((Icons.chat_bubble, const Color(0xFF30B0C7)),
                            label: false),
                        _icon((Icons.music_note, const Color(0xFFFF2D55)),
                            label: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Voile sombre : met la fenêtre blanche en avant.
        Container(color: Colors.black.withValues(alpha: 0.30)),
      ],
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

class _HomePageState extends State<HomePage> {
  late int _tab = widget.initialTab;
  late final int _captureSub = widget.initialSub;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Retour vers la fenêtre rapide (écran racine).
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: PressPop(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context)
                            .popUntil((r) => r.isFirst),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _surfaceStrong,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chevron_left,
                                  size: 18, color: _textPrimary),
                              Text('Fenêtre rapide',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
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
            Icon(icon, size: 44, color: const Color(0xFFCCCCE0)),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    fontSize: 14, color: _textSecondary, height: 1.5)),
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
  @override
  Widget build(BuildContext context) {
    final notes = store.notes;
    final body = notes.isEmpty
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
                              style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary)),
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
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: _textSecondary, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(formatStamp(n.createdAt),
                        style: GoogleFonts.montserrat(
                            fontSize: 11, color: const Color(0xFFBBBBCC))),
                  ],
                ),
              );
            },
          );
    return embedded ? body : _Page(title: 'Notes', child: body);
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
    final active = all.where((t) => !t.archived).toList();
    final done = all.where((t) => t.done).toList()
      ..sort((a, b) =>
          (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));
    final list = _showArchive ? done : active;

    final body = Column(
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
    );
    return widget.embedded ? body : _Page(title: 'To-Do', child: body);
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
                    color: selected ? Colors.white : _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
          'Touche « Tap Back » puis To-Do pour ajouter une tâche.');

  /// Feuille d'édition : modifier le texte et ajouter/compléter
  /// la description d'une tâche.
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

  Widget _description(Todo t) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        t.description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.montserrat(
            fontSize: 12, color: _textSecondary, height: 1.4),
      ),
    );
  }

  Widget _activeTile(Todo t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: _card,
      child: Row(
        children: [
          IconButton(
            icon: Icon(t.done
                ? Icons.check_circle
                : Icons.radio_button_unchecked),
            color: t.done ? Colors.green : _textSecondary,
            onPressed: () => store.toggleTodo(t.id),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editTodo(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.text,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      decoration:
                          t.done ? TextDecoration.lineThrough : null,
                      color: t.done
                          ? const Color(0xFFBBBBCC)
                          : _textPrimary,
                    ),
                  ),
                  if (t.description.isNotEmpty) _description(t),
                  if (t.done)
                    Text('Fait · retiré de la liste dans 24 h',
                        style: GoogleFonts.montserrat(
                            fontSize: 11, color: _textSecondary)),
                ],
              ),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editTodo(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.text,
                      style: GoogleFonts.montserrat(
                          color: _textSecondary,
                          decoration: TextDecoration.lineThrough)),
                  if (t.description.isNotEmpty) _description(t),
                  const SizedBox(height: 4),
                  Text('Créée : ${formatStamp(t.createdAt)}',
                      style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: const Color(0xFFBBBBCC))),
                  if (t.doneAt != null)
                    Text('Faite : ${formatStamp(t.doneAt!)}',
                        style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.green.shade600)),
                ],
              ),
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
  final bool embedded;
  const ReadingScreen({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    final items = store.reading;
    final body = items.isEmpty
        ? const _Empty(Icons.bookmark_border, 'Rien à lire pour l\'instant',
            'Touche « Tap Back » puis « À lire » pour garder un lien/texte et programmer un rappel.')
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              decoration: it.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: it.done
                                  ? const Color(0xFFBBBBCC)
                                  : _textPrimary,
                            ),
                          ),
                          if (it.remindAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                  '⏰ ${formatStamp(it.remindAt!)}',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.orange.shade700)),
                            ),
                          Text('Ajouté : ${formatStamp(it.createdAt)}',
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: const Color(0xFFBBBBCC))),
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
          );
    return embedded ? body : _Page(title: 'À lire', child: body);
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
            Tab(text: '🎙️ Notes'),
            Tab(text: '✅ To-Do'),
            Tab(text: '🔖 À lire'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _c,
            children: const [
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

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = store.events;
    return _Page(
      title: 'Agenda',
      trailing: PressPop(
        child: IconButton(
          icon: const Icon(Icons.add, color: _textPrimary),
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
          icon: const Icon(Icons.add, color: _textPrimary),
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
                            icon: const Icon(Icons.delete_outline, size: 20),
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
                                  color: const Color(0xFFBBBBCC))),
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
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.image_outlined),
            label: Text(
                imageB64 == null ? 'Ajouter une image' : 'Image ajoutée ✓',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            onPressed: () async {
              final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1280,
                  imageQuality: 80);
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
                              child: const Icon(Icons.edit,
                                  size: 15, color: Colors.white),
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
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(50),
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
                              style: GoogleFonts.montserrat()),
                          backgroundColor: _textPrimary,
                        ),
                      );
                    },
                    child: Text('Enregistrer',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700)),
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
          // Tap Back
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Tap Back',
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
                    const Icon(Icons.touch_app_outlined,
                        color: _textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fenêtre de commande rapide',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ouvre la mini-fenêtre Shortist comme si tu tapotais l\'arrière de ton iPhone.',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, color: _textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                PressPop(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _textPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.smart_button_outlined, size: 20),
                    label: Text('Tester Tap Back',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700)),
                    onPressed: () => tapBackTrigger.value++,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Fond affiché derrière la fenêtre rapide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wallpaper_outlined,
                        color: _textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fond derrière la fenêtre',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'iOS ne permet pas d\'afficher le vrai écran d\'accueil derrière une app. '
                  'Astuce : fais une capture d\'écran de TON écran d\'accueil, puis choisis-la ici. '
                  'Le rendu sera identique à ton iPhone.',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, color: _textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                PressPop(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPrimary,
                      side: const BorderSide(color: _border),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 20),
                    label: Text(
                        store.panelWallpaperB64 == null
                            ? 'Choisir ma capture d\'écran'
                            : 'Capture définie ✓ — changer',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1500,
                          imageQuality: 85);
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      await store.savePanelWallpaper(base64Encode(bytes));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                if (store.panelWallpaperB64 != null) ...[
                  const SizedBox(height: 8),
                  PressPop(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () async {
                        await store.savePanelWallpaper(null);
                        if (mounted) setState(() {});
                      },
                      child: Text('Retirer la capture',
                          style: GoogleFonts.montserrat(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
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
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Text(label,
          style:
              GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15)),
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
          side: const BorderSide(color: _border),
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.schedule),
        label: Text(label,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
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
  const CommandPanel({super.key});
  @override
  State<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends State<CommandPanel> {
  _Mode _mode = _Mode.choices;

  final _noteTitle = TextEditingController();
  final _noteBody = TextEditingController();
  final _todoText = TextEditingController();
  final _todoDesc = TextEditingController();
  final List<TextEditingController> _readControllers = [
    TextEditingController()
  ];
  String _remindKey = '';
  DateTime? _customDateTime;

  // Rafraîchit la liste des tâches chaque minute pour faire disparaître
  // celles cochées depuis plus de 30 min.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  static const _remindOptions = [
    ('1h', 'Dans 1 h'),
    ('eve', 'Ce soir 20h'),
    ('tom', 'Demain 9h'),
    ('3d', 'Dans 3 j'),
  ];

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _ticker?.cancel();
    _noteTitle.dispose();
    _noteBody.dispose();
    _todoText.dispose();
    _todoDesc.dispose();
    for (final c in _readControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ferme la fenêtre rapide : l'app retourne en arrière-plan
  /// (écran d'accueil de l'iPhone) et le panneau revient au menu.
  void _close() {
    FocusScope.of(context).unfocus();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      minimizeApp();
    }
    setState(() {
      _mode = _Mode.choices;
      _noteTitle.clear();
      _noteBody.clear();
      _todoText.clear();
      _todoDesc.clear();
    });
  }

  /// Seule porte d'entrée vers l'accueil complet de l'app.
  void _openApp({int tab = 0, int sub = 0}) {
    FocusScope.of(context).unfocus();
    setState(() => _mode = _Mode.choices);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HomePage(initialTab: tab, initialSub: sub),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Le panneau est collé au bord supérieur PHYSIQUE de l'écran : son fond
    // blanc passe sous l'encoche / la Dynamic Island, et seul le contenu
    // respecte la safe area. Coins arrondis en bas uniquement → la fenêtre
    // semble sortir de l'encoche de l'iPhone.
    final topInset = MediaQuery.paddingOf(context).top;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        // Entrée en glissant depuis le haut, avec un léger rebond
        // (le panneau est recréé à chaque tap-back via sa clé,
        // donc l'animation rejoue).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.translate(
            offset: Offset(0, (1 - v) * -460),
            child: child,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, topInset + 6, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildMode(),
                      ),
                    ),
                    // Petite poignée décorative en bas du panneau.
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const SizedBox(width: 34),
              Expanded(
                child: Center(
                  child: Text('Shortist',
                      style: GoogleFonts.montserrat(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                ),
              ),
              InkWell(
                onTap: _close,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F3),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _cmd(Icons.edit_note, 'Note',
                () => setState(() => _mode = _Mode.note)),
            const SizedBox(width: 8),
            _cmd(Icons.add_task, 'To-Do',
                () => setState(() => _mode = _Mode.todo)),
            const SizedBox(width: 8),
            _cmd(Icons.bookmark_add_outlined, 'À lire',
                () => setState(() => _mode = _Mode.reading)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _cmdWide(Icons.menu_book, 'Voir les notes',
                  () => _openApp(sub: 0)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cmdWide(Icons.checklist, 'Voir To-Do',
                  () => _openApp(sub: 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Seul accès vers l'accueil complet de l'application.
        _PanelButton(
          onTap: () => _openApp(),
          filledDark: true,
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ouvrir l\'application',
                  style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cmd(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: _PanelButton(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: Colors.black),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _cmdWide(IconData icon, String label, VoidCallback onTap) {
    return _PanelButton(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
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
            style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black)),
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
          _close();
        }),
      ],
    );
  }

  Widget _todoPanel() {
    return ListenableBuilder(
      key: const ValueKey('todo'),
      listenable: store,
      builder: (context, _) {
        final recent = store.quickPanelTodos;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head('To-Do'),
            const SizedBox(height: 10),
            _field(_todoText, 'Nouvelle tâche…', autofocus: true),
            const SizedBox(height: 8),
            _field(_todoDesc, 'Description (optionnel)…'),
            const SizedBox(height: 10),
            _primary('Ajouter', () {
              final text = _todoText.text.trim();
              if (text.isEmpty) return;
              store.addTodo(Todo(
                id: _uid(),
                createdAt: DateTime.now(),
                text: text,
                description: _todoDesc.text.trim(),
              ));
              _todoText.clear();
              _todoDesc.clear();
            }),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Dernières tâches',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontSize: 13)),
              const SizedBox(height: 6),
              ...recent.map(_quickTodoTile),
            ],
          ],
        );
      },
    );
  }

  /// Tâche dans la fenêtre rapide : coche pour marquer « fait ».
  /// Une tâche cochée disparaît d'ici au bout de 30 min, mais reste
  /// dans l'historique de l'accueil de l'app.
  Widget _quickTodoTile(Todo t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
                t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22),
            color: t.done ? Colors.green : Colors.black38,
            onPressed: () => store.toggleTodo(t.id),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    color: t.done ? Colors.black38 : Colors.black,
                  ),
                ),
                if (t.done)
                  Text('Fait ✓ — disparaîtra d\'ici 30 min',
                      style: GoogleFonts.montserrat(
                          fontSize: 10, color: Colors.black38)),
              ],
            ),
          ),
        ],
      ),
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
        Text(
          'Garde un lien ou un texte à lire plus tard. Programme un rappel.',
          style: GoogleFonts.montserrat(
              color: Colors.black54, fontSize: 13, height: 1.4),
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
              () => setState(
                  () => _readControllers.add(TextEditingController()))),
        ),
        const SizedBox(height: 14),
        Text('⏰ Me le rappeler',
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 14)),
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
            color: on ? const Color(0xFF1C1C2E) : Colors.white,
            border: Border.all(
                color: on ? const Color(0xFF1C1C2E) : Colors.black12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: GoogleFonts.montserrat(
                  color: on ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );
    }

    final widgets = _remindOptions
        .map((o) =>
            chip(o.$1, o.$2, () => setState(() => _remindKey = o.$1)))
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
      initialTime:
          TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _customDateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
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
          id: _uid(),
          createdAt: DateTime.now(),
          text: text,
          remindAt: remindAt);
      store.addReading(item);
      if (remindAt != null) {
        Notifications.schedule(
            id: item.notificationId, body: text, when: remindAt);
      }
    }
    _close();
  }

  Widget _chip(String label, VoidCallback onTap) {
    return _PanelButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(label,
          style: GoogleFonts.montserrat(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {bool autofocus = false, int maxLines = 1, VoidCallback? onSubmit}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: maxLines,
      style:
          GoogleFonts.montserrat(color: Colors.black, fontSize: 16),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: Colors.black38),
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
    return _PanelButton(
      onTap: onTap,
      filledDark: true,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16)),
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

/// Bouton utilisé dans le CommandPanel (fond blanc ou sombre).
class _PanelButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool filledDark;
  final EdgeInsets padding;
  const _PanelButton({
    required this.child,
    required this.onTap,
    this.filledDark = false,
    this.padding =
        const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
  });
  @override
  State<_PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<_PanelButton> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.filledDark
                ? const Color(0xFF1C1C2E)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: widget.filledDark
                ? null
                : Border.all(
                    color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: widget.filledDark ? 0.18 : 0.07),
                blurRadius: widget.filledDark ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
