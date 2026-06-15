import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'bridge.dart';
import 'models.dart';
import 'store.dart';

String _uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

const _textSec = Color(0x8CFFFFFF);

// ── Demo Page ─────────────────────────────────────────────────────────────────

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                const SizedBox(height: 48),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 48,
                  runSpacing: 36,
                  children: const [
                    _IPhone16Frame(),
                    _SidePanel(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Column(
    children: [
      Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: 0.22), blurRadius: 28, spreadRadius: 4),
          ],
        ),
        child: const Icon(Icons.bolt, color: Colors.black, size: 34),
      ),
      const SizedBox(height: 18),
      const Text('Shortist',
          style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
      const SizedBox(height: 8),
      const Text('Un geste. Une capture. Partout.',
          style: TextStyle(color: Colors.white54, fontSize: 15)),
    ],
  );

}

// ── iPhone 16 Frame ───────────────────────────────────────────────────────────

class _IPhone16Frame extends StatelessWidget {
  const _IPhone16Frame();

  // Dimensions du chassis
  static const _outerW = 240.0;
  static const _outerH = 500.0;
  static const _border = 11.0;
  static const _cornerOuter = 52.0;
  static const _cornerInner = _cornerOuter - _border;
  // Dimensions de l'écran interne
  static const screenW = _outerW - 2 * _border;   // 218
  static const screenH = _outerH - 2 * _border;   // 478

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _outerW + 10,
      height: _outerH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corps du téléphone (titane satiné)
          Positioned(
            left: 5, right: 5, top: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3C3C3E), Color(0xFF1C1C1E), Color(0xFF2A2A2C)],
                  stops: [0, 0.55, 1],
                ),
                borderRadius: BorderRadius.circular(_cornerOuter),
                border: Border.all(color: const Color(0xFF48484A), width: 0.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.85), blurRadius: 64, offset: const Offset(0, 32), spreadRadius: -12),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.04), blurRadius: 1, spreadRadius: 1),
                ],
              ),
            ),
          ),

          // Écran
          Positioned(
            left: 5 + _border, right: 5 + _border,
            top: _border, bottom: _border,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cornerInner),
              child: const _PhoneApp(),
            ),
          ),

          // Dynamic Island
          Positioned(
            top: _border + 8,
            child: Container(
              width: 88, height: 26,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),

          // Boutons physiques gauche
          const Positioned(left: 2, top: 94,  child: _PhysBtn(w: 4, h: 30)),  // mute
          const Positioned(left: 2, top: 136, child: _PhysBtn(w: 4, h: 58)),  // vol +
          const Positioned(left: 2, top: 206, child: _PhysBtn(w: 4, h: 58)),  // vol -
          // Bouton droit (power)
          const Positioned(right: 2, top: 150, child: _PhysBtn(w: 4, h: 82)),

          // Reflet haut de l'écran
          Positioned(
            left: 5 + _border, right: 5 + _border, top: _border,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.white.withValues(alpha: 0.15), Colors.transparent],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhysBtn extends StatelessWidget {
  final double w, h;
  const _PhysBtn({required this.w, required this.h});

  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF3A3A3C), Color(0xFF252527)],
      ),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

// ── Wallpaper iOS Aurora ──────────────────────────────────────────────────────

class _IosWallpaper extends StatelessWidget {
  const _IosWallpaper();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WallpaperPainter(),
    size: Size.infinite,
  );
}

class _WallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fond sombre bleu nuit
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A0E22), Color(0xFF060912), Color(0xFF0C071A)],
      ).createShader(rect));

    // Halo bleu — haut
    _glow(canvas, size, Offset(size.width * 0.28, size.height * 0.10), size.width * 0.7,
        const Color(0xFF1D4ED8), 0.48);
    // Halo indigo — centre gauche
    _glow(canvas, size, Offset(size.width * 0.05, size.height * 0.50), size.width * 0.55,
        const Color(0xFF4F46E5), 0.32);
    // Halo violet — droite haute
    _glow(canvas, size, Offset(size.width * 0.88, size.height * 0.28), size.width * 0.50,
        const Color(0xFF7C3AED), 0.38);
    // Halo cyan — bas centre
    _glow(canvas, size, Offset(size.width * 0.50, size.height * 0.88), size.width * 0.55,
        const Color(0xFF0EA5E9), 0.22);
    // Halo rose — bas droite (subtil)
    _glow(canvas, size, Offset(size.width * 0.92, size.height * 0.78), size.width * 0.38,
        const Color(0xFFBE185D), 0.16);
  }

  void _glow(Canvas canvas, Size size, Offset c, double r, Color color, double alpha) {
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r)));
  }

  @override
  bool shouldRepaint(_WallpaperPainter _) => false;
}

// ── App interactive dans le téléphone ────────────────────────────────────────

enum _Panel { closed, choices, note, todo, reading }

class _PhoneApp extends StatefulWidget {
  const _PhoneApp();

  @override
  State<_PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends State<_PhoneApp> with SingleTickerProviderStateMixin {
  int _tab = 0;
  _Panel _panel = _Panel.closed;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    store.addListener(_rebuild);
    tapBackTrigger.addListener(_onTrigger);
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  void _onTrigger() {
    if (!mounted) return;
    if (_panel == _Panel.closed) {
      setState(() => _panel = _Panel.choices);
      _anim.forward(from: 0);
    } else {
      _closePanel();
    }
  }

  void _openPanel() {
    setState(() => _panel = _Panel.choices);
    _anim.forward(from: 0);
  }

  void _closePanel() {
    _anim.reverse().then((_) {
      if (mounted) setState(() => _panel = _Panel.closed);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    store.removeListener(_rebuild);
    tapBackTrigger.removeListener(_onTrigger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Wallpaper
        const _IosWallpaper(),

        // UI de l'app
        Column(
          children: [
            _StatusBar(),
            const SizedBox(height: 4),
            _PhoneTabBar(tab: _tab, onTab: (i) => setState(() => _tab = i)),
            Expanded(child: _tabContent()),
            _PhoneBottomNav(),
          ],
        ),

        // FAB Tap Back
        Positioned(
          bottom: 12, left: 0, right: 0,
          child: Center(
            child: _TapBackFab(onTap: _openPanel),
          ),
        ),

        // Overlay dim animé
        if (_panel != _Panel.closed)
          FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: _closePanel,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

        // Panneau de commande
        if (_panel != _Panel.closed)
          Positioned(
            top: 46, left: 10, right: 10,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: _PhoneCommandPanel(
                  panel: _panel,
                  onPanel: (p) => setState(() => _panel = p),
                  onClose: _closePanel,
                  onTabSwitch: (i) {
                    setState(() => _tab = i);
                    _closePanel();
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 0:  return _PhoneNotesList(notes: store.notes);
      case 1:  return _PhoneTodosList(todos: store.todos.where((t) => !t.archived).toList());
      default: return _PhoneReadingList(items: store.reading.where((r) => !r.done).toList());
    }
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 48, 14, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('9:41',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        Row(children: const [
          Icon(Icons.signal_cellular_alt, color: Colors.white, size: 12),
          SizedBox(width: 3),
          Icon(Icons.wifi, color: Colors.white, size: 12),
          SizedBox(width: 3),
          Icon(Icons.battery_full, color: Colors.white, size: 12),
        ]),
      ],
    ),
  );
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _PhoneTabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _PhoneTabBar({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
    child: Row(
      children: [
        _t('🎙️ Notes', 0),
        const SizedBox(width: 4),
        _t('✅ To-Do', 1),
        const SizedBox(width: 4),
        _t('🔖 À lire', 2),
      ],
    ),
  );

  Widget _t(String label, int i) => Expanded(
    child: GestureDetector(
      onTap: () => onTab(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: tab == i
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: tab == i ? Colors.white : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

// ── Vues des onglets ──────────────────────────────────────────────────────────

class _PhoneNotesList extends StatelessWidget {
  final List<Note> notes;
  const _PhoneNotesList({required this.notes});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return _emptyState(Icons.mic_none, 'Aucune note', 'Tap Back → Note');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 70),
      itemCount: notes.length,
      itemBuilder: (_, i) => _itemCard(
        title: notes[i].title,
        body: notes[i].body,
        time: _stamp(notes[i].createdAt),
      ),
    );
  }
}

class _PhoneTodosList extends StatelessWidget {
  final List<Todo> todos;
  const _PhoneTodosList({required this.todos});

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return _emptyState(Icons.checklist, 'Aucune tâche', 'Tap Back → To-Do');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 70),
      itemCount: todos.length,
      itemBuilder: (_, i) {
        final t = todos[i];
        return GestureDetector(
          onTap: () => store.toggleTodo(t.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: t.done ? Colors.greenAccent : Colors.white38, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.text,
                      style: TextStyle(
                          color: t.done ? Colors.white38 : Colors.white,
                          fontSize: 11,
                          decoration: t.done ? TextDecoration.lineThrough : null)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhoneReadingList extends StatelessWidget {
  final List<ReadItem> items;
  const _PhoneReadingList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyState(Icons.bookmark_border, 'Rien à lire', 'Tap Back → À lire');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 70),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemCard(
        title: items[i].text,
        body: '',
        time: _stamp(items[i].createdAt),
      ),
    );
  }
}

Widget _itemCard({required String title, required String body, required String time}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(body, maxLines: 2, style: const TextStyle(color: _textSec, fontSize: 9.5)),
          ],
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
        ],
      ),
    );

Widget _emptyState(IconData icon, String title, String hint) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white24, size: 30),
      const SizedBox(height: 8),
      Text(title,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(hint,
          style: const TextStyle(color: Colors.white30, fontSize: 10)),
    ],
  ),
);

String _stamp(DateTime d) {
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (same(d, now)) return "Aujourd'hui $hm";
  if (same(d, now.subtract(const Duration(days: 1)))) return 'Hier $hm';
  return '${d.day}/${d.month} $hm';
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _PhoneBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: const Color(0xCC111114),
      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Icon(Icons.dynamic_feed, color: Colors.white, size: 18),
        Icon(Icons.event, color: Colors.white30, size: 18),
        SizedBox(width: 50),
        Icon(Icons.menu_book, color: Colors.white30, size: 18),
        Icon(Icons.settings_outlined, color: Colors.white30, size: 18),
      ],
    ),
  );
}

// ── FAB Tap Back ──────────────────────────────────────────────────────────────

class _TapBackFab extends StatefulWidget {
  final VoidCallback onTap;
  const _TapBackFab({required this.onTap});

  @override
  State<_TapBackFab> createState() => _TapBackFabState();
}

class _TapBackFabState extends State<_TapBackFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(
          scale: 1 - _press.value * 0.08,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
              BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: Colors.black, size: 14),
              SizedBox(width: 5),
              Text('Tap Back',
                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Panneau de commande dans le téléphone ─────────────────────────────────────

class _PhoneCommandPanel extends StatefulWidget {
  final _Panel panel;
  final ValueChanged<_Panel> onPanel;
  final VoidCallback onClose;
  final ValueChanged<int> onTabSwitch;
  const _PhoneCommandPanel({
    required this.panel,
    required this.onPanel,
    required this.onClose,
    required this.onTabSwitch,
  });

  @override
  State<_PhoneCommandPanel> createState() => _PhoneCommandPanelState();
}

class _PhoneCommandPanelState extends State<_PhoneCommandPanel> {
  final _noteTitle = TextEditingController();
  final _noteBody  = TextEditingController();
  final _todoText  = TextEditingController();
  final _readText  = TextEditingController();
  String? _readImageB64;

  @override
  void dispose() {
    _noteTitle.dispose();
    _noteBody.dispose();
    _todoText.dispose();
    _readText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    switch (widget.panel) {
      case _Panel.choices: return _choices();
      case _Panel.note:    return _noteForm();
      case _Panel.todo:    return _todoForm();
      case _Panel.reading: return _readForm();
      case _Panel.closed:  return const SizedBox();
    }
  }

  // ── Choix principal ──

  Widget _choices() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Shortist',
            style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        const SizedBox(height: 10),
        Row(children: [
          _actionBtn(Icons.edit_note, 'Note', () => widget.onPanel(_Panel.note)),
          const SizedBox(width: 7),
          _actionBtn(Icons.add_task, 'To-Do', () => widget.onPanel(_Panel.todo)),
          const SizedBox(width: 7),
          _actionBtn(Icons.bookmark_add_outlined, 'À lire', () => widget.onPanel(_Panel.reading)),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _wideBtn(Icons.menu_book, 'Voir les notes', () => widget.onTabSwitch(0))),
          const SizedBox(width: 7),
          Expanded(child: _wideBtn(Icons.checklist, 'Voir To-Do', () => widget.onTabSwitch(1))),
        ]),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4, offset: const Offset(0,1))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.black),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black)),
          ],
        ),
      ),
    ),
  );

  Widget _wideBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4, offset: const Offset(0,1))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: Colors.black),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black)),
        ),
      ]),
    ),
  );

  // ── Formulaire Note ──

  Widget _noteForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _backRow('Note'),
      const SizedBox(height: 10),
      _field(_noteTitle, 'Titre…', autofocus: true),
      const SizedBox(height: 7),
      _field(_noteBody, 'Corps de la note…', maxLines: 3),
      const SizedBox(height: 6),
      // Avertissement suppression 24h
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          '⚡ Suppression auto après 24h · Déplace vers « À lire » pour conserver sans limite',
          style: TextStyle(fontSize: 9.5, color: Color(0xFFE65100), height: 1.4),
        ),
      ),
      const SizedBox(height: 10),
      _saveBtn('Enregistrer', () {
        final t = _noteTitle.text.trim();
        final b = _noteBody.text.trim();
        if (t.isEmpty && b.isEmpty) return;
        store.addNote(Note(id: _uid(), createdAt: DateTime.now(), title: t.isEmpty ? 'Note' : t, body: b));
        widget.onTabSwitch(0);
      }),
    ],
  );

  // ── Formulaire To-Do ──

  Widget _todoForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _backRow('To-Do'),
      const SizedBox(height: 10),
      _field(_todoText, 'Nouvelle tâche…', autofocus: true),
      const SizedBox(height: 10),
      _saveBtn('Ajouter', () {
        final t = _todoText.text.trim();
        if (t.isEmpty) return;
        store.addTodo(Todo(id: _uid(), createdAt: DateTime.now(), text: t));
        widget.onTabSwitch(1);
      }),
    ],
  );

  // ── Formulaire À lire ──

  Widget _readForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _backRow('À lire plus tard'),
      const SizedBox(height: 10),
      _field(_readText, 'Lien ou texte à retenir…', autofocus: true),
      const SizedBox(height: 8),
      // Sélecteur d'image
      GestureDetector(
        onTap: _pickReadImage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _readImageB64 == null ? 'Ajouter une image…' : 'Image ajoutée ✓',
                  style: TextStyle(
                    fontSize: 12,
                    color: _readImageB64 == null
                        ? Colors.black38
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
              if (_readImageB64 != null)
                GestureDetector(
                  onTap: () => setState(() => _readImageB64 = null),
                  child: const Icon(Icons.close, size: 14, color: Colors.black38),
                ),
            ],
          ),
        ),
      ),
      // Aperçu image sélectionnée
      if (_readImageB64 != null) ...[
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(_readImageB64!),
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
      const SizedBox(height: 10),
      _saveBtn('Enregistrer', () {
        final t = _readText.text.trim();
        if (t.isEmpty && _readImageB64 == null) return;
        store.addReading(ReadItem(
          id: _uid(),
          createdAt: DateTime.now(),
          text: t,
          imageB64: _readImageB64,
        ));
        widget.onTabSwitch(2);
      }),
    ],
  );

  Future<void> _pickReadImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() => _readImageB64 = base64Encode(bytes));
    } catch (_) {}
  }

  // ── Shared helpers ──

  Widget _backRow(String title) => Row(
    children: [
      GestureDetector(
        onTap: () => widget.onPanel(_Panel.choices),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: const Color(0xFFF0F0F3), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.chevron_left, color: Colors.black, size: 20),
        ),
      ),
      const SizedBox(width: 9),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
    ],
  );

  Widget _field(TextEditingController c, String hint, {bool autofocus = false, int maxLines = 1}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
          filled: true,
          fillColor: const Color(0xFFF2F2F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  Widget _saveBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFF0A0A0C), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    ),
  );
}

// ── Panneau latéral (bouton simuler) ─────────────────────────────────────────

class _SidePanel extends StatefulWidget {
  const _SidePanel();

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300), lowerBound: 0.45)
      ..repeat(reverse: true);
    tapBackTrigger.addListener(_onTrigger);
  }

  void _onTrigger() {
    if (mounted) setState(() => _active = !_active);
  }

  @override
  void dispose() {
    _pulse.dispose();
    tapBackTrigger.removeListener(_onTrigger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre explication
          const Text('Comment ça marche',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // Étape 1
          _step('1', 'Appuie sur\n⚡ Tap Back',
              sub: 'depuis n\'importe quel écran'),
          const SizedBox(height: 10),
          // Étape 2
          _step('2', 'Choisis une action',
              sub: 'Note · To-Do · À lire'),
          const SizedBox(height: 10),
          // Étape 3
          _step('3', 'Sauvegardé !',
              sub: 'retrouve tout dans l\'app'),

          const SizedBox(height: 28),

          // Flèche animée
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Opacity(
              opacity: _active ? 0 : _pulse.value,
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, color: Colors.white38, size: 15),
                const SizedBox(width: 6),
                Text('Essaie ici',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bouton Tap Back externe
          GestureDetector(
            onTap: () => tapBackTrigger.value++,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: _active
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _active ? Colors.white30 : Colors.transparent, width: 1.5),
                boxShadow: _active
                    ? null
                    : [
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.26),
                            blurRadius: 22,
                            spreadRadius: 3),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt,
                      color: _active ? Colors.white : Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _active ? 'Fermer' : 'Tap Back',
                    style: TextStyle(
                        color: _active ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

          // Info sous le bouton
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _active ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                '✨ Le panneau s\'ouvre\ndans l\'écran du téléphone.\nInteragis directement !',
                style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String num, String title, {required String sub}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22, height: 22,
        margin: const EdgeInsets.only(top: 1, right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(num,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
            Text(sub,
                style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
          ],
        ),
      ),
    ],
  );
}
