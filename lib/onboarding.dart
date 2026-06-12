// Onboarding — « avant-page » affichée à la première ouverture, avant
// d'accéder à l'application.
//
// Deux modes, au choix de l'utilisateur (bascule en haut de l'écran) :
//  • Images : tutoriel détaillé en 9 pages (captures dans
//    assets/onboarding/etape_1.png … etape_9.png).
//  • Vidéo  : tutoriel en 3 parties — Installation sur Raccourcis,
//    Installation sur Paramètres, Test (assets/onboarding/videos/*.mp4).
//
// La dernière page propose « Configurer maintenant » (ouvre les Réglages
// d'accessibilité iOS) ou « Passer pour l'instant » ; les deux mènent à
// l'app et ne remontrent plus jamais cette avant-page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'bridge.dart';
import 'store.dart';

const _bg       = Color(0xFFF5F5FA);
const _surface  = Color(0xFFFFFFFF);
const _textPrim = Color(0xFF1C1C2E);
const _textSec  = Color(0xFF888898);
const _border   = Color(0xFFEAEAF2);
const _accent   = Color(0xFF1C1C2E);

// ── Contenu du tutoriel ─────────────────────────────────────────────────────

class _TutoPage {
  final IconData icon;
  final String title;
  final String text;
  const _TutoPage(this.icon, this.title, this.text);

  /// Capture associée : assets/onboarding/etape_1.png … etape_9.png.
  String assetFor(int index) => 'assets/onboarding/etape_${index + 1}.png';
}

const _pages = <_TutoPage>[
  _TutoPage(
    Icons.touch_app_outlined,
    'Bienvenue sur Shortist',
    'Capture une note, une tâche ou un lien en 2 secondes, depuis n\'importe quelle app, d\'un simple double-tap au dos de ton iPhone.',
  ),
  _TutoPage(
    Icons.dashboard_customize_outlined,
    'Le panneau rapide',
    'Le panneau s\'affiche par-dessus l\'écran en cours : Note, To-Do, À lire et tes dernières tâches à cocher — sans ouvrir l\'application.',
  ),
  _TutoPage(
    Icons.app_shortcut_outlined,
    'Ouvre l\'app Raccourcis',
    'Sur ton iPhone, ouvre l\'application « Raccourcis » (préinstallée par Apple). C\'est elle qui relie Shortist au double-tap.',
  ),
  _TutoPage(
    Icons.add_circle_outline,
    'Ajoute le raccourci Shortist',
    'Dans l\'onglet Raccourcis, touche « + » puis cherche « Shortist ». Choisis l\'action « Ouvrir le panneau » et valide : le raccourci est créé.',
  ),
  _TutoPage(
    Icons.settings_outlined,
    'Ouvre les Réglages iOS',
    'Va maintenant dans Réglages → Accessibilité → Toucher.',
  ),
  _TutoPage(
    Icons.back_hand_outlined,
    '« Toucher le dos »',
    'Tout en bas de la page Toucher, ouvre « Toucher le dos » (Back Tap).',
  ),
  _TutoPage(
    Icons.touch_app,
    'Choisis « Toucher deux fois »',
    'Sélectionne « Toucher deux fois », puis dans la liste des raccourcis, choisis « Shortist ».',
  ),
  _TutoPage(
    Icons.play_circle_outline,
    'Teste ton installation',
    'Double-tape le dos de ton iPhone : le panneau Shortist apparaît par-dessus n\'importe quel écran. 🎉',
  ),
  _TutoPage(
    Icons.check_circle_outline,
    'C\'est prêt !',
    'Note, To-Do, À lire, Agenda, Carnet… tout est capturé instantanément et se retrouve dans l\'app. Bonne capture !',
  ),
];

/// Les 3 parties du tutoriel vidéo : (titre, fichier, icône).
const _videoParts = <(String, String, IconData)>[
  ('Installation sur Raccourcis', 'assets/onboarding/videos/raccourcis.mp4',
      Icons.app_shortcut_outlined),
  ('Installation sur Paramètres', 'assets/onboarding/videos/parametres.mp4',
      Icons.settings_outlined),
  ('Test', 'assets/onboarding/videos/test.mp4', Icons.play_circle_outline),
];

// ── Écran principal ─────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _videoMode = false; // false = Images, true = Vidéo
  int _videoPart = 0;
  Set<String> _assets = const {};

  bool get _lastPage => _page == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  /// Liste les assets réellement embarqués pour savoir quelles captures /
  /// vidéos existent (les manquantes affichent un emplacement par défaut).
  Future<void> _loadManifest() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (mounted) setState(() => _assets = manifest.listAssets().toSet());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool configure}) async {
    await store.markBackTapSetupDone();
    if (configure) openAccessibilitySettings();
    if (mounted) Navigator.of(context).pushReplacementNamed('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            _modeSwitch(),
            const SizedBox(height: 10),
            Expanded(child: _videoMode ? _videoSection() : _imageSection()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Bascule Images / Vidéo ────────────────────────────────────────────────

  Widget _modeSwitch() {
    Widget seg(String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? _accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18,
                    color: selected ? Colors.white : _textSec),
                const SizedBox(width: 7),
                Text(label,
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : _textSec)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          seg('Images', Icons.photo_library_outlined, !_videoMode,
              () => setState(() => _videoMode = false)),
          seg('Vidéo', Icons.play_circle_outline, _videoMode,
              () => setState(() => _videoMode = true)),
        ],
      ),
    );
  }

  // ── Mode Images : 9 pages ────────────────────────────────────────────────

  Widget _imageSection() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _tutoPageView(_pages[i], i),
          ),
        ),
        const SizedBox(height: 10),
        _dots(),
      ],
    );
  }

  Widget _tutoPageView(_TutoPage p, int index) {
    final asset = p.assetFor(index);
    final hasImage = _assets.contains(asset);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // Illustration : la capture si elle existe, sinon une grande icône.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: _textPrim.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? Image.asset(asset, fit: BoxFit.contain)
                  : Center(
                      child: Icon(p.icon, size: 84,
                          color: _textPrim.withValues(alpha: 0.18)),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Étape ${index + 1} sur ${_pages.length}',
              style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textSec,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Text(p.title,
              style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textPrim,
                  height: 1.2)),
          const SizedBox(height: 10),
          Text(p.text,
              style: GoogleFonts.montserrat(
                  fontSize: 16, color: _textSec, height: 1.55)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _page ? 20 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _page ? _accent : _border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  // ── Mode Vidéo : 3 parties ───────────────────────────────────────────────

  Widget _videoSection() {
    final (title, asset, icon) = _videoParts[_videoPart];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // Sélecteur de partie (1/2/3).
          Row(
            children: [
              for (int i = 0; i < _videoParts.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _partChip(i)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.montserrat(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _textPrim)),
          const SizedBox(height: 4),
          Text('Partie ${_videoPart + 1} sur ${_videoParts.length}',
              style: GoogleFonts.montserrat(fontSize: 13, color: _textSec)),
          const SizedBox(height: 14),
          Expanded(
            child: _VideoCard(
              // La clé force un nouveau lecteur (et libère l'ancien)
              // à chaque changement de partie.
              key: ValueKey(asset),
              asset: asset,
              exists: _assets.contains(asset),
              placeholderIcon: icon,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _partChip(int i) {
    final selected = i == _videoPart;
    final (_, _, icon) = _videoParts[i];
    // Libellé court pour les puces (le titre complet est affiché au-dessus).
    final short = switch (i) {
      0 => 'Raccourcis',
      1 => 'Paramètres',
      _ => 'Test',
    };
    return GestureDetector(
      onTap: () => setState(() => _videoPart = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _accent : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _accent : _border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : _textSec),
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

  // ── Barre du bas : Suivant / Configurer / Passer ─────────────────────────

  Widget _bottomBar() {
    final showConfigure = _videoMode || _lastPage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PrimaryButton(
            label: showConfigure ? 'Configurer maintenant' : 'Suivant',
            trailingIcon: showConfigure
                ? Icons.arrow_forward_ios
                : Icons.arrow_forward,
            onTap: () {
              if (showConfigure) {
                _finish(configure: true);
              } else {
                _pageCtrl.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic);
              }
            },
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _finish(configure: false),
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
    );
  }
}

// ── Lecteur vidéo d'une partie du tutoriel ──────────────────────────────────

class _VideoCard extends StatefulWidget {
  final String asset;
  final bool exists;
  final IconData placeholderIcon;
  const _VideoCard(
      {super.key,
      required this.asset,
      required this.exists,
      required this.placeholderIcon});

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
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _textPrim.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (!widget.exists) {
      // Emplacement vide : la vidéo n'a pas encore été déposée dans assets/.
      return Container(
        decoration: box,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.placeholderIcon,
                size: 64, color: _textPrim.withValues(alpha: 0.18)),
            const SizedBox(height: 16),
            Text(
              'Vidéo à venir.\n\nDépose le fichier\n${widget.asset.split('/').last}\ndans assets/onboarding/videos/.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: _textSec, height: 1.6),
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
        child: const CircularProgressIndicator(strokeWidth: 2.5),
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
            // Bouton lecture quand la vidéo est en pause.
            if (!c.value.isPlaying)
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 42),
                ),
              ),
            // Barre de progression en bas de la carte.
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

// ── Bouton principal réutilisable ───────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData trailingIcon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.trailingIcon, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.25),
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
              const SizedBox(width: 7),
              Icon(widget.trailingIcon, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
