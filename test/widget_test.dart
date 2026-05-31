// Test de fumée : l'app se construit et affiche l'écran Notes + le bouton Tap Back.

import 'package:flutter_test/flutter_test.dart';

import 'package:tapbacknote/main.dart';

void main() {
  testWidgets('L\'app démarre et affiche Tap Back', (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    await tester.pump();

    // Le titre de l'écran Notes et le bouton flottant sont présents.
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Tap Back'), findsOneWidget);
  });

  testWidgets('Le bouton Tap Back ouvre la fenêtre de commande',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TapBackApp());
    await tester.pump();

    await tester.tap(find.text('Tap Back'));
    await tester.pumpAndSettle();

    // Les 4 actions apparaissent (« To-Do » existe aussi dans la barre d'onglets).
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('To-Do'), findsWidgets);
    expect(find.text('Rechercher'), findsOneWidget);
    expect(find.text('Voir les notes'), findsOneWidget);
  });
}
