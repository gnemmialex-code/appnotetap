// Test de fumée : l'app se construit et affiche l'écran Notes + le bouton Tap Back.

import 'package:flutter_test/flutter_test.dart';

import 'package:tapbacknote/main.dart';

void main() {
  testWidgets('L\'app démarre et affiche Tap Back', (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    await tester.pump();

    // L'onglet Capture (Notes/To-Do/À lire) et le bouton flottant sont présents.
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Tap Back'), findsOneWidget);
  });

  testWidgets('Le bouton Tap Back ouvre la fenêtre de commande',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    await tester.pump();

    await tester.tap(find.text('Tap Back'));
    await tester.pumpAndSettle();

    // Les actions apparaissent (« To-Do » et « À lire » existent aussi en onglet).
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('To-Do'), findsWidgets);
    expect(find.text('À lire'), findsWidgets);
    expect(find.text('Voir les notes'), findsOneWidget);
  });
}
