import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/analysis_flow_test.dart' as flow;
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

/// Parcourt la présentation et les résultats d'analyse.
Future<void> visitAnalysisScreens(WidgetTester tester) async {
  for (final input in ['xn--pypal-4ve.com', 'mailto:contact@exemple.bf']) {
    await flow.enterText(tester, input);
    await flow.analyze(tester, 'Analyser le lien');
    expect(tester.takeException(), isNull, reason: input);
    await flow.scrollTo(tester, find.text('Détails techniques'));
    await tester.tap(find.text('Détails techniques'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$input (détails)');
    await flow.pressBack(tester);
  }
  await flow.selectMessageMode(tester);
  await flow.enterText(tester, flow.scamMessage);
  await flow.analyze(tester, 'Analyser le message');
  expect(tester.takeException(), isNull, reason: 'message');
  final link = find.text('http://orange-gain.xyz/retrait');
  await flow.scrollTo(tester, link);
  await tester.tap(link);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'lien du message');
}

Future<void> visitOnboarding(WidgetTester tester) async {
  for (var step = 0; step < 2; step++) {
    expect(tester.takeException(), isNull, reason: 'étape ${step + 1}');
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull, reason: 'étape 3');
}

void main() {
  testWidgets('analyse et résultats : 320 dp, texte à 200 %', (tester) async {
    await pumpSafeLinkApp(tester, size: const Size(320, 640), textScale: 2);
    await visitAnalysisScreens(tester);
  });

  testWidgets('présentation : 320 dp, texte à 200 %', (tester) async {
    await pumpSafeLinkApp(
      tester,
      size: const Size(320, 640),
      textScale: 2,
      onboarded: false,
    );
    await visitOnboarding(tester);
  });

  testWidgets('analyse et résultats : format de référence', (tester) async {
    await pumpSafeLinkApp(tester);
    await visitAnalysisScreens(tester);
  });

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
