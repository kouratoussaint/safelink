import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';

/// Parcourt tous les écrans ; tout débordement de mise en page fait échouer
/// le test (exception levée par le moteur de rendu).
Future<void> visitAllScreens(WidgetTester tester) async {
  for (final tab in ['Historique', 'Conseils', 'Paramètres']) {
    await tapDestination(tester, tab);
    expect(tester.takeException(), isNull, reason: tab);
  }
  await tester.tap(find.text('À propos de SafeLink'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'À propos');
}

void main() {
  testWidgets('petit écran (320 dp) avec texte agrandi à 200 %', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull, reason: 'Accueil');
    await visitAllScreens(tester);
  });

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    testWidgets('libellés de navigation sur une ligne ($width dp, 200 %)', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester, size: Size(width, 800), textScale: 2);
      double heightOf(String label) => tester
          .getSize(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
          )
          .height;
      final reference = heightOf('Accueil');
      for (final label in ['Historique', 'Conseils', 'Paramètres']) {
        expect(heightOf(label), reference, reason: '« $label » sur une ligne');
      }
      // Le contenu, lui, garde le grossissement demandé.
      final body = tester.widget<Text>(find.text('Vérifiez avant de cliquer.'));
      expect(body.textScaler, isNull);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('Vérifiez avant de cliquer.')),
        ).scale(10),
        20,
      );
    });
  }

  testWidgets('format de référence 393 × 852 dp', (tester) async {
    await pumpSafeLinkApp(tester);
    expect(tester.takeException(), isNull, reason: 'Accueil');
    await visitAllScreens(tester);
  });
}
