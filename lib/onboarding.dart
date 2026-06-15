// Onboarding en 2 phases :
//   1. Présentation de l'app (5 slides animés, design sombre)
//   2. Installation (3 vidéos : raccourcis, paramètres, test)
//
// L'ensemble ne s'affiche qu'une seule fois (flag backTapSetupDone).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'bridge.dart';
import 'store.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _SlideData {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final String tag;
  final bool isShowcase;
  const _SlideData(this.icon, this.title, this.body, this.accent,
      {this.tag = '', this.isShowcase = false});
}

const _slides = <_SlideData>[
  _SlideData(
    Icons.touch_app_rounded,
    'Capturez en 2 secondes',
    'Un double-tap au dos de votre iPhone — le panneau Shortist apparaît par-dessus n\'importe quel écran.',
    Color(0xFF7C5CBF),
    tag: '⚡ Instantané',
  ),
  _SlideData(
    Icons.flash_on_rounded,
    'Notes & To-Do instantanés',
    'Ajoutez une note rapide, cochez une tâche ou sauvegardez un lien — sans quitter votre application.',
    Color(0xFF00A876),
    tag: '📱 Depuis n\'importe où',
  ),
  _SlideData(
    Icons.event_note_rounded,
    'Agenda synchronisé',
    'Consultez et créez des événements directement dans votre Calendrier iPhone, depuis Shortist.',
    Color(0xFF1A86CF),
    tag: '🗓️ Calendrier iPhone',
  ),
  _SlideData(
    Icons.bookmark_add_rounded,
    'Rien ne se perd',
    'Liens, images, idées — tout est capturé, organisé et consultable en un instant avec rappels.',
    Color(0xFFE06542),
    tag: '🔖 Tout organisé',
  ),
  _SlideData(
    Icons.auto_awesome_rounded,
    'Et bien plus encore…',
    'Widget, Carnet personnel, thème sombre, rappels — Shortist évolue avec vous, chaque jour.',
    Color(0xFFAB47BC),
    tag: '✨ Toujours plus',
    isShowcase: true,
  ),
];

const _showcaseFeatures = <(IconData, String)>[
  (Icons.widgets_rounded, 'Widget'),
  (Icons.menu_book_rounded, 'Carnet'),
  (Icons.dark_mode_rounded, 'Thème'),
  (Icons.cloud_done_rounded, 'iCloud'),
  (Icons.notifications_active_rounded, 'Rappels'),
  (Icons.person_rounded, 'Profil'),
];

const _videoParts = <(String, String, IconData)>[
  ('Installation sur Raccourcis', 'assets/onboarding/videos/raccourcis.mp4',
      Icons.app_shortcut_outlined),
  ('Installation sur Paramètres', 'assets/onboarding/videos/parametres.mp4',
      Icons.settings_outlined),
  ('Test du double-tap', 'assets/onboarding/videos/test.mp4',
      Icons.play_circle_outline),
];

// ── OnboardingScreen ──────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _showInstallation = false;

  void _goToInstallation() => setState(() => _showInstallation = true);

  Future<void> _finish({required bool configure}) async {
    await store.markBackTapSetupDone();
    if (configure) openAccessibilitySettings();
    if (mounted) Navigator.of(context).pushReplacementNamed('/app');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
      child: _showInstallation
          ? _InstallationPhase(
              key: const ValueKey('install'), onFinish: _finish)
          : _PresentationPhase(
              key: const ValueKey('present'), onNext: _goToInstallation),
    );
  }
}

// ── Phase 1 : Présentation ────────────────────────────────────────────────────

class _PresentationPhase extends StatefulWidget {
  final VoidCallback onNext;
  const _PresentationPhase({super.key, required this.onNext});
  @override
  State<_PresentationPhase> createState() => _PresentationPhaseState();
}

class _PresentationPhaseState extends State<_PresentationPhase> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onNext();
    } else {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _slides[_page].accent;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      body: Stack(
        children: [
          // Ambient top glow — suit la couleur d'accent
          AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            width: double.infinity,
            height: 380,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.65),
                radius: 0.9,
                colors: [
                  accent.withValues(alpha: 0.20),
                  accent.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Ambient bottom glow
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 12, 0),
                  child: Row(
                    children: [
                      Text('Shortist',
                          style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onNext,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Text('Installer',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white38)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: Colors.white24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Slides ───────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _SlideCard(
                      key: ValueKey(i),
                      data: _slides[i],
                      isActive: i == _page,
                    ),
                  ),
                ),
                // ── Dots ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          width: i == _page ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? accent
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Bouton ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  child: _PresentButton(
                    label: _isLast ? 'Installer Shortist' : 'Suivant',
                    accent: accent,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide animé ───────────────────────────────────────────────────────────────

class _SlideCard extends StatefulWidget {
  final _SlideData data;
  final bool isActive;
  const _SlideCard({super.key, required this.data, required this.isActive});
  @override
  State<_SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<_SlideCard> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  // ── Animations d'entrée ──────────────────────────────────────────────────
  late final Animation<double> _iconScale = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.0, 0.65, curve: Curves.elasticOut)));

  late final Animation<double> _iconOpacity = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));

  late final Animation<double> _glowScale = Tween(begin: 0.2, end: 1.0)
      .animate(CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));

  late final Animation<Offset> _titleSlide =
      Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(
              parent: _enter,
              curve:
                  const Interval(0.22, 0.75, curve: Curves.easeOutCubic)));

  late final Animation<double> _titleFade = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.22, 0.65, curve: Curves.easeOut)));

  late final Animation<Offset> _bodySlide =
      Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
              parent: _enter,
              curve:
                  const Interval(0.44, 0.9, curve: Curves.easeOutCubic)));

  late final Animation<double> _bodyFade = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.44, 0.9, curve: Curves.easeOut)));

  // ── Flottement ───────────────────────────────────────────────────────────
  late final Animation<double> _floatY = Tween(begin: -10.0, end: 10.0)
      .animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _enter.forward();
  }

  @override
  void didUpdateWidget(_SlideCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    _ring.dispose();
    super.dispose();
  }

  // ── Showcase grid (dernière slide) ────────────────────────────────────────

  Widget _showcaseItem(int i, Color accent) {
    final (icon, label) = _showcaseFeatures[i];
    final start = 0.06 + i * 0.10;
    final end = (start + 0.38).clamp(0.0, 1.0);
    final fadeEnd = (start + 0.22).clamp(0.0, 1.0);
    final scaleAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _enter,
          curve: Interval(start, end, curve: Curves.elasticOut)),
    );
    final fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _enter,
          curve: Interval(start, fadeEnd, curve: Curves.easeOut)),
    );
    return ScaleTransition(
      scale: scaleAnim,
      child: FadeTransition(
        opacity: fadeAnim,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.13),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.30), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: accent),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseGrid(Color accent) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _float]),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _floatY.value * 0.35),
        child: Opacity(
          opacity: _iconOpacity.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 20,
        children: [
          for (int i = 0; i < _showcaseFeatures.length; i++)
            _showcaseItem(i, accent),
        ],
      ),
    );
  }

  // ── Zone icône (slides 1-4) ───────────────────────────────────────────────

  Widget _buildIconArea(Color accent) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _float, _ring]),
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _floatY.value),
        child: Opacity(
          opacity: _iconOpacity.value,
          child: Transform.scale(
            scale: _iconScale.value,
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer halo
                  Transform.scale(
                    scale: _glowScale.value,
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.24),
                            accent.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Anneau tournant extérieur
                  Transform.rotate(
                    angle: _ring.value * 2 * math.pi,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.14),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                  // Anneau tournant inverse (plus lent)
                  Transform.rotate(
                    angle: -_ring.value * 2 * math.pi * 0.55,
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                  // Orbiting dot 1 — rapide, rayon moyen
                  Positioned(
                    left: 115 +
                        86 * math.cos(_ring.value * 2 * math.pi) -
                        5,
                    top: 115 +
                        86 * math.sin(_ring.value * 2 * math.pi) -
                        5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent
                            .withValues(alpha: _iconOpacity.value * 0.75),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Orbiting dot 2 — plus lent, grand rayon, déphasé
                  Positioned(
                    left: 115 +
                        100 *
                            math.cos(_ring.value * 2 * math.pi * 0.6 +
                                math.pi * 0.9) -
                        4,
                    top: 115 +
                        100 *
                            math.sin(_ring.value * 2 * math.pi * 0.6 +
                                math.pi * 0.9) -
                        4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent
                            .withValues(alpha: _iconOpacity.value * 0.45),
                      ),
                    ),
                  ),
                  // Orbiting dot 3 — sens inverse, petit, blanc
                  Positioned(
                    left: 115 +
                        74 *
                            math.cos(-_ring.value * 2 * math.pi * 1.2 +
                                math.pi * 0.5) -
                        3,
                    top: 115 +
                        74 *
                            math.sin(-_ring.value * 2 * math.pi * 1.2 +
                                math.pi * 0.5) -
                        3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: _iconOpacity.value * 0.28),
                      ),
                    ),
                  ),
                  // Cercle intérieur + icône
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.13),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.32),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(widget.data.icon, size: 62, color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.data.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Zone icône ou grille showcase
          if (widget.data.isShowcase)
            _buildShowcaseGrid(accent)
          else
            _buildIconArea(accent),
          SizedBox(height: widget.data.isShowcase ? 30 : 44),
          // Tag chip
          if (widget.data.tag.isNotEmpty) ...[
            FadeTransition(
              opacity: _titleFade,
              child: _TagChip(text: widget.data.tag, accent: accent),
            ),
            const SizedBox(height: 14),
          ],
          // Titre
          SlideTransition(
            position: _titleSlide,
            child: FadeTransition(
              opacity: _titleFade,
              child: Text(
                widget.data.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Corps
          SlideTransition(
            position: _bodySlide,
            child: FadeTransition(
              opacity: _bodyFade,
              child: Text(
                widget.data.body,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 15.5,
                  color: Colors.white.withValues(alpha: 0.58),
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String text;
  final Color accent;
  const _TagChip({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Phase 2 : Installation ────────────────────────────────────────────────────

class _InstallationPhase extends StatefulWidget {
  final void Function({required bool configure}) onFinish;
  const _InstallationPhase({super.key, required this.onFinish});
  @override
  State<_InstallationPhase> createState() => _InstallationPhaseState();
}

class _InstallationPhaseState extends State<_InstallationPhase> {
  int _part = 0;
  Set<String> _assets = const {};

  static const _bg = Color(0xFFF5F5FA);
  static const _surface = Color(0xFFFFFFFF);
  static const _textPrim = Color(0xFF1C1C2E);
  static const _textSec = Color(0xFF888898);
  static const _border = Color(0xFFEAEAF2);

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (mounted) setState(() => _assets = manifest.listAssets().toSet());
  }

  @override
  Widget build(BuildContext context) {
    final (title, asset, icon) = _videoParts[_part];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _textPrim.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Installation · ~3 min',
                        style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textSec)),
                  ),
                  const SizedBox(height: 8),
                  Text('Mise en place',
                      style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _textPrim)),
                  const SizedBox(height: 4),
                  Text('Regarde les 3 vidéos pour activer le double-tap.',
                      style: GoogleFonts.montserrat(
                          fontSize: 14, color: _textSec, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ── Chips de partie ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (int i = 0; i < _videoParts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _partChip(i)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Titre + vidéo ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrim)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _VideoCard(
                        key: ValueKey(asset),
                        asset: asset,
                        exists: _assets.contains(asset),
                        placeholderIcon: icon,
                        surface: _surface,
                        border: _border,
                        textSec: _textSec,
                        textPrim: _textPrim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Boutons bas ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InstallButton(
                    label: 'Configurer maintenant',
                    onTap: () => widget.onFinish(configure: true),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => widget.onFinish(configure: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Passer pour l\'instant',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                            color: _textSec,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partChip(int i) {
    final selected = i == _part;
    final icon = _videoParts[i].$3;
    final short = switch (i) {
      0 => 'Raccourcis',
      1 => 'Paramètres',
      _ => 'Test',
    };
    return GestureDetector(
      onTap: () => setState(() => _part = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _textPrim : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _textPrim : _border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : _textSec),
            const SizedBox(height: 4),
            Text(short,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _textPrim)),
          ],
        ),
      ),
    );
  }
}

// ── Lecteur vidéo ─────────────────────────────────────────────────────────────

class _VideoCard extends StatefulWidget {
  final String asset;
  final bool exists;
  final IconData placeholderIcon;
  final Color surface;
  final Color border;
  final Color textSec;
  final Color textPrim;
  const _VideoCard({
    super.key,
    required this.asset,
    required this.exists,
    required this.placeholderIcon,
    required this.surface,
    required this.border,
    required this.textSec,
    required this.textPrim,
  });
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.exists) {
      final c = VideoPlayerController.asset(widget.asset);
      _ctrl = c;
      c.initialize().then((_) {
        if (mounted) setState(() {});
      });
      c.setLooping(true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: widget.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: widget.border),
      boxShadow: [
        BoxShadow(
          color: widget.textPrim.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (!widget.exists) {
      return Container(
        decoration: box,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.placeholderIcon,
                size: 64, color: widget.textPrim.withValues(alpha: 0.18)),
            const SizedBox(height: 16),
            Text(
              'Vidéo à venir.\n\nDépose le fichier\n${widget.asset.split('/').last}\ndans assets/onboarding/videos/.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: widget.textSec, height: 1.6),
            ),
          ],
        ),
      );
    }

    final c = _ctrl!;
    if (!c.value.isInitialized) {
      return Container(
        decoration: box,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: widget.textPrim.withValues(alpha: 0.4)),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        decoration: box,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
            if (!c.value.isPlaying)
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: widget.textPrim.withValues(alpha: 0.82),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 42),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Boutons ───────────────────────────────────────────────────────────────────

class _PresentButton extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _PresentButton(
      {required this.label, required this.accent, required this.onTap});
  @override
  State<_PresentButton> createState() => _PresentButtonState();
}

class _PresentButtonState extends State<_PresentButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.48),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _InstallButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _InstallButton({required this.label, required this.onTap});
  @override
  State<_InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<_InstallButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1C1C2E).withValues(alpha: 0.26),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.label,
                  style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  size: 13, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
