// Test de fumée : l'app démarre sur la fenêtre rapide ; l'accueil complet
// ne s'ouvre que via le bouton « Ouvrir l'application ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tapbacknote/main.dart';

void main() {
  testWidgets('L\'app démarre sur la fenêtre rapide', (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    await tester.pump();

    // Le panneau de choix est visible, pas l'accueil complet.
    expect(find.text('Shortist'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('To-Do'), findsOneWidget);
    expect(find.text('À lire'), findsOneWidget);
    expect(find.text('Voir les notes'), findsOneWidget);
    expect(find.text('Ouvrir l\'application'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);

    // Démonte l'arbre pour annuler le Timer périodique du panneau.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('« Ouvrir l\'application » mène à l\'accueil complet',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    // Laisse finir l'animation d'entrée du panneau avant de taper.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Ouvrir l\'application'));
    await tester.pumpAndSettle();

    // L'accueil complet (barre d'onglets) est affiché.
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Agenda'), findsWidgets);
    expect(find.text('Fenêtre rapide'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
