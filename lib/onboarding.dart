import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bridge.dart';
import 'store.dart';

const _bg = Color(0xFF000000);
const _surface = Color(0x14FFFFFF);
const _textSecondary = Color(0x8CFFFFFF);

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                children: [
                  const Icon(Icons.touch_app_outlined,
                      color: Colors.white, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    'Active le Tap-back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Double-tape le dos de ton iPhone pour ouvrir\nShortist en un instant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: _textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 36),
                  const _Step(
                    n: '1',
                    title: 'Ouvre l\'app Raccourcis',
                    body:
                        'Lance l\'app "Raccourcis" sur ton iPhone (icône bleue avec des engrenages).',
                  ),
                  const _Step(
                    n: '2',
                    title: 'Crée un raccourci "Shortist"',
                    body:
                        'Appuie sur  +  → Ajouter une action → cherche "Ouvrir une URL".\nColle l\'URL ci-dessous, nomme le raccourci Shortist, puis sauvegarde.',
                    urlChip: 'shortist://tapback',
                  ),
                  const _Step(
                    n: '3',
                    title: 'Configure la Touche arrière',
                    body:
                        'Réglages  →  Accessibilité  →  Toucher  →  Touche arrière\n→  Deux taps  →  Raccourcis  →  Shortist',
                    showSettingsButton: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 44),
              child: _DoneButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String title;
  final String body;
  final String? urlChip;
  final bool showSettingsButton;

  const _Step({
    required this.n,
    required this.title,
    required this.body,
    this.urlChip,
    this.showSettingsButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 5),
                Text(body,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 13, height: 1.55)),
                if (urlChip != null) ...[
                  const SizedBox(height: 10),
                  _UrlChip(url: urlChip!),
                ],
                if (showSettingsButton) ...[
                  const SizedBox(height: 12),
                  const _OpenSettingsButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlChip extends StatefulWidget {
  final String url;
  const _UrlChip({required this.url});

  @override
  State<_UrlChip> createState() => _UrlChipState();
}

class _UrlChipState extends State<_UrlChip> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.url));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2),
            () { if (mounted) setState(() => _copied = false); });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : Icons.copy_outlined,
              size: 14,
              color: _copied ? Colors.greenAccent : Colors.white54,
            ),
            const SizedBox(width: 7),
            Text(
              widget.url,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenSettingsButton extends StatelessWidget {
  const _OpenSettingsButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: openAccessibilitySettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.settings_outlined, size: 16, color: Colors.black),
            SizedBox(width: 7),
            Text('Ouvrir Accessibilité',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await store.markBackTapSetupDone();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/app');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'C\'est fait — Ouvrir Shortist  →',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 17),
        ),
      ),
    );
  }
}
