import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bridge.dart';
import 'store.dart';

const _bg         = Color(0xFFF5F5FA);
const _surface    = Color(0xFFFFFFFF);
const _textPrim   = Color(0xFF1C1C2E);
const _textSec    = Color(0xFF888898);
const _border     = Color(0xFFEAEAF2);
const _accent     = Color(0xFF1C1C2E);

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              // Icône
              Container(
                width: 88,
                height: 88,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _textPrim.withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.touch_app_outlined,
                    color: _textPrim, size: 44),
              ),
              // Titre
              Text(
                '"Shortist" souhaite\nutiliser le Tap-back',
                style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _textPrim,
                    height: 1.25),
              ),
              const SizedBox(height: 14),
              // Description
              Text(
                'Double-tape le dos de ton iPhone pour ouvrir instantanément le panneau de commande, depuis n\'importe où.',
                style: GoogleFonts.montserrat(
                    fontSize: 15, color: _textSec, height: 1.6),
              ),
              const SizedBox(height: 28),
              // Chemin de navigation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _textPrim.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dans les Réglages iOS :',
                        style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: _textSec,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                    const SizedBox(height: 10),
                    _pathRow([
                      'Accessibilité',
                      'Toucher',
                      'Touche arrière',
                      'Deux taps',
                      'Shortist',
                    ]),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // Bouton principal
              _ConfigureButton(),
              const SizedBox(height: 12),
              // Bouton secondaire
              _SecondaryButton(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pathRow(List<String> steps) {
    final List<Widget> children = [];
    for (int i = 0; i < steps.length; i++) {
      final isLast = i == steps.length - 1;
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isLast ? _accent : const Color(0xFFEEEEF6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            steps[i],
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isLast ? Colors.white : _textPrim,
            ),
          ),
        ),
      );
      if (!isLast) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.chevron_right, size: 16, color: _textSec),
        ));
      }
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: children,
    );
  }
}

class _ConfigureButton extends StatefulWidget {
  @override
  State<_ConfigureButton> createState() => _ConfigureButtonState();
}

class _ConfigureButtonState extends State<_ConfigureButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () async {
        await store.markBackTapSetupDone();
        openAccessibilitySettings();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/app');
        }
      },
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
              Text('Configurer maintenant',
                  style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios,
                  size: 13, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await store.markBackTapSetupDone();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/app');
        }
      },
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
    );
  }
}
