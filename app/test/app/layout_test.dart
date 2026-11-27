import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_controller.dart';

import '../features/analysis_flow_test.dart' as flow;
import '../features/help_flow_test.dart' as help;
import '../features/history_flow_test.dart' as history;
import '../features/online_flow_test.dart' as online;
import '../features/share_flow_test.dart' as share;
import '../helpers/pump_app.dart';
import '../history/history_store_test.dart' show entryOf, secretUrl;

/// Parcourt tous les écrans ; tout débordement de mise en page fait échouer
/// le test (exception levée par le moteur de rendu).
Future<void> visitAllScreens(WidgetTester tester) async {
  for (final tab in ['Historique', 'Conseils', 'Paramètres']) {
    await tapDestination(tester, tab);
    expect(tester.takeException(), isNull, reason: tab);
  }
  await tester.scrollUntilVisible(find.text('À propos de SafeLink'), 200);
  await tester.ensureVisible(find.text('À propos de SafeLink'));
  await tester.pumpAndSettle();
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

/// Conseils, aide, exemples et confidentialité ; chaque fiche ouverte.
Future<void> visitHelpScreens(WidgetTester tester) async {
  for (final id in [
    'victime', 'codes', 'transfert', 'ussd', 'agents', 'applis', 'gains', //
    'emploi', 'liens', 'qr', 'urgence',
  ]) {
    await help.goTo(tester, '/conseils/$id');
    expect(tester.takeException(), isNull, reason: 'fiche $id');
    await flow.scrollTo(tester, find.text('Vérifier un lien ou un message'));
    expect(tester.takeException(), isNull, reason: 'fiche $id (bas)');
  }
  for (final location in [
    '/conseils',
    '/accueil/aide',
    '/accueil/aide/exemples',
    '/parametres/confidentialite',
    '/nulle-part',
  ]) {
    await help.goTo(tester, location);
    expect(tester.takeException(), isNull, reason: location);
  }
}

/// Mode simple : déplie chaque raison, chaque geste et les explications.
Future<void> visitSimpleScreens(WidgetTester tester) async {
  Future<void> openAll() async {
    for (final label in [
      'Lettres trompeuses',
      'Ne touchez pas le lien',
      'Voir les explications',
    ]) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        await flow.scrollTo(tester, finder);
      }
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  }

  await flow.enterText(tester, 'xn--pypal-4ve.com');
  await flow.analyze(tester, 'Analyser le lien');
  expect(tester.takeException(), isNull, reason: 'lien');
  await openAll();
  await flow.pressBack(tester);
  await flow.selectMessageMode(tester);
  await flow.enterText(tester, flow.scamMessage);
  await flow.analyze(tester, 'Analyser le message');
  expect(tester.takeException(), isNull, reason: 'message');
  await flow.scrollTo(tester, find.text('Voir les explications'));
  await tester.tap(find.text('Voir les explications'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'message déplié');
}

Future<void> visitOnboarding(WidgetTester tester) async {
  for (var step = 0; step < 3; step++) {
    expect(tester.takeException(), isNull, reason: 'étape ${step + 1}');
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull, reason: 'étape 4');
}

Future<void> visitHistory(WidgetTester tester) async {
  await tapDestination(tester, 'Historique');
  expect(tester.takeException(), isNull, reason: 'Historique');
  await flow.scrollTo(tester, find.text('secure-login.xyz'));
  await tester.tap(find.text('secure-login.xyz'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'fiche');
  await flow.scrollTo(tester, find.text('Analyser à nouveau'));
  expect(tester.takeException(), isNull, reason: 'fiche (bas)');
}

Future<void> visitOnlineResult(WidgetTester tester) async {
  await history.analyzeLink(tester, 'https://lefaso.net/');
  expect(tester.takeException(), isNull, reason: 'résultat en ligne');
  await flow.scrollTo(tester, find.text('Vérifications en ligne'));
  await flow.scrollTo(tester, find.text('Ce qui a été vérifié'));
  await flow.scrollTo(tester, find.text('Détails techniques'));
  expect(tester.takeException(), isNull, reason: 'sections en ligne');
}

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (referenceSize, 1.0),
  ]) {
    testWidgets('résultat vérifié en ligne : ${size.width} dp, × $scale', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        size: size,
        textScale: scale,
        online: OnlineChoice.enabled,
        onlineChecker: online.cleanChecker(),
      );
      await visitOnlineResult(tester);
    });
  }

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (referenceSize, 1.0),
  ]) {
    testWidgets('historique et fiche : ${size.width} dp, texte × $scale', (
      tester,
    ) async {
      final backend = await history.filledBackend([
        entryOf(AnalysisKind.link, secretUrl).withContent(secretUrl),
        entryOf(AnalysisKind.message, flow.scamMessage),
      ]);
      await pumpSafeLinkApp(
        tester,
        size: size,
        textScale: scale,
        preferences: history.enabled,
        historyBackend: backend,
      );
      await visitHistory(tester);
    });
  }

  testWidgets('analyse et résultats : 320 dp, texte à 200 %', (tester) async {
    await pumpSafeLinkApp(tester, size: const Size(320, 640), textScale: 2);
    await visitAnalysisScreens(tester);
  });

  testWidgets('mode simple : 320 dp, texte à 200 %, tout déplié', (
    tester,
  ) async {
    await pumpSafeLinkApp(
      tester,
      size: const Size(320, 640),
      textScale: 2,
      expert: false,
    );
    await visitSimpleScreens(tester);
  });

  testWidgets('mode simple : format de référence, tout déplié', (tester) async {
    await pumpSafeLinkApp(tester, expert: false);
    await visitSimpleScreens(tester);
  });

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (referenceSize, 1.0),
  ]) {
    testWidgets('partage reçu : ${size.width} dp, texte × $scale', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        size: size,
        textScale: scale,
        expert: false,
      );
      await share.visitShareScreens(tester);
    });
  }

  testWidgets('conseils, aide, confidentialité : 320 dp, texte à 200 %', (
    tester,
  ) async {
    await pumpSafeLinkApp(
      tester,
      size: const Size(320, 640),
      textScale: 2,
      expert: false,
      googleKey: 'test-key',
    );
    await visitHelpScreens(tester);
  });

  testWidgets('conseils, aide, confidentialité : format de référence', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester, expert: false, googleKey: 'test-key');
    await visitHelpScreens(tester);
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
