import 'package:flutter/material.dart';

import 'bridge.dart';
import 'store.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.touch_app_outlined,
                    color: Colors.white, size: 44),
              ),
              // Titre
              const Text(
                '"Shortist" souhaite\nutiliser le Tap-back',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25),
              ),
              const SizedBox(height: 14),
              // Description
              const Text(
                'Double-tape le dos de ton iPhone pour ouvrir instantanément le panneau de commande, depuis n\'importe où.',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0x99FFFFFF),
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              // Chemin de navigation — style pill
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dans les Réglages iOS :',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0x66FFFFFF),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
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
              const SizedBox(height: 14),
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
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: i == steps.length - 1
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            steps[i],
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: i == steps.length - 1 ? Colors.black : Colors.white,
            ),
          ),
        ),
      );
      if (i < steps.length - 1) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.chevron_right, size: 16, color: Color(0x55FFFFFF)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Configurer maintenant',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black),
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
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Passer pour l\'instant',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
