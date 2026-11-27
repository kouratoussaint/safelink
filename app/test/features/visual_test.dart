import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';

import '../helpers/fake_google.dart';
import '../helpers/fake_online.dart';
import '../helpers/fake_speaker.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;
import 'history_flow_test.dart' as history;

/// Lien qui imite PayPal avec une lettre cyrillique.
const lookalike = 'xn--pypal-4ve.com';

Future<FakeSpeaker> pumpSimple(
  WidgetTester tester, {
  FakeSpeaker? speaker,
  OnlineChoice online = OnlineChoice.disabled,
  OnlineChecker? checker,
}) async {
  final fake = speaker ?? FakeSpeaker();
  await pumpSafeLinkApp(
    tester,
    expert: false,
    speaker: fake,
    online: online,
    onlineChecker: checker,
  );
  return fake;
}

void main() {
  group('mode simple (par défaut)', () {
    testWidgets('verdict en grand : mot d’alerte, jauge, phrase simple', (
      tester,
    ) async {
      await pumpSimple(tester);
      await history.analyzeLink(tester, lookalike);
      expect(find.text('Attention !'), findsOneWidget);
      expect(find.text('Lien suspect'), findsOneWidget);
      expect(
        find.text('Ce lien ressemble à un piège. Ne l’ouvrez pas.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Niveau de risque : Attention'),
        findsOneWidget,
      );
      expect(find.text('Confiance : élevée'), findsNothing);
    });

    testWidgets('raisons en mots courts, explication au toucher', (
      tester,
    ) async {
      await pumpSimple(tester);
      await history.analyzeLink(tester, lookalike);
      await flow.scrollTo(tester, find.text('Lettres trompeuses'));
      expect(find.text('Indice fort'), findsNothing);
      expect(find.textContaining('alphabet'), findsNothing);
      await tester.tap(find.text('Lettres trompeuses'));
      await tester.pumpAndSettle();
      expect(find.textContaining('alphabet'), findsWidgets);
    });

    testWidgets('gestes en vignettes ; détails techniques cachés', (
      tester,
    ) async {
      await pumpSimple(tester);
      await history.analyzeLink(tester, lookalike);
      await flow.scrollTo(tester, find.text('Ne touchez pas le lien'));
      expect(find.text('N’ouvrez pas ce lien.'), findsNothing);
      await tester.tap(find.text('Ne touchez pas le lien'));
      await tester.pumpAndSettle();
      expect(find.text('N’ouvrez pas ce lien.'), findsOneWidget);

      await flow.scrollTo(tester, find.text('Voir les explications'));
      expect(find.text('Détails techniques'), findsNothing);
      expect(find.text('Ce qui n’a pas été vérifié'), findsNothing);
      await tester.tap(find.text('Voir les explications'));
      await tester.pumpAndSettle();
      await flow.scrollTo(tester, find.text('Ce qui n’a pas été vérifié'));
      expect(find.text('Cacher les explications'), findsOneWidget);
      expect(find.text('Détails techniques'), findsNothing);
    });

    testWidgets('« Écouter » lit le verdict et les gestes en mots simples', (
      tester,
    ) async {
      final speaker = await pumpSimple(tester);
      await history.analyzeLink(tester, lookalike);
      await tester.tap(flow.button('Écouter'));
      await tester.pumpAndSettle();
      expect(speaker.spoken, hasLength(1));
      final text = speaker.spoken.single;
      expect(text, startsWith('Attention ! Lien suspect.'));
      expect(text, contains('Lettres trompeuses.'));
      expect(text, contains('Que faire : Ne touchez pas le lien.'));
      expect(text, isNot(contains('URL_')));
    });

    testWidgets('lecture en cours : « Arrêter » l’interrompt', (tester) async {
      final speaker = FakeSpeaker()..gate = Completer<void>();
      await pumpSimple(tester, speaker: speaker);
      await history.analyzeLink(tester, lookalike);
      await tester.tap(flow.button('Écouter'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Arrêter'), findsOneWidget);
      await tester.tap(flow.button('Arrêter'));
      await tester.pumpAndSettle();
      expect(speaker.stops, 1);
      expect(find.text('Écouter'), findsOneWidget);
    });

    testWidgets('pas de voix française : message clair', (tester) async {
      await pumpSimple(tester, speaker: FakeSpeaker(available: false));
      await history.analyzeLink(tester, lookalike);
      await tester.tap(flow.button('Écouter'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La lecture à voix haute n’est pas disponible sur ce téléphone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('danger : le téléphone vibre', (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpSimple(
        tester,
        online: OnlineChoice.enabled,
        checker: fakeChecker(
          dns: FakeDohTransport(blockedByQuad9: {'lefaso.net'}),
        ),
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(find.text('Danger !'), findsOneWidget);
      expect(find.text('Signalé comme dangereux'), findsWidgets);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    });

    testWidgets('animations réduites : tout est affiché d’emblée', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpSimple(tester);
      await history.analyzeLink(tester, lookalike);
      final opacities = tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.text('Attention !'),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(opacities.every((f) => f.opacity.value == 1), isTrue);
    });

    testWidgets('message : synthèse en grand, aperçu du premier lien', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
        googleKey: 'test-key',
        onlineChecker: OnlineChecker(
          dns: FakeDohTransport(),
          json: FakeJsonTransport(),
          safeBrowsing: fakeSafeBrowsing(),
        ),
        pagePreviewClient: fakePreview(),
      );
      await history.analyzeMessage(
        tester,
        'Votre compte sera bloqué aujourd’hui. Confirmez votre code PIN '
        'ici : https://lefaso.net/compte',
      );
      expect(find.text('Danger !'), findsOneWidget);
      expect(find.textContaining('Synthèse'), findsOneWidget);
      await flow.scrollTo(tester, find.text('Aperçu de la page'));
      expect(
        find.bySemanticsLabel('Photo de la page, prise par Google'),
        findsOneWidget,
      );
    });
  });

  group('accueil', () {
    testWidgets('grandes vignettes Lien / Message, choix annoncé', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSimple(tester);
      expect(find.text('Une adresse internet'), findsOneWidget);
      expect(find.text('Un SMS, un message WhatsApp'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Lien')),
        isSemantics(isSelected: true, isButton: true),
      );
      await flow.selectMessageMode(tester);
      expect(
        tester.getSemantics(find.text('Message')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(find.text('Analyser le message'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('mode expert : réglage enregistré, détails affichés', (
    tester,
  ) async {
    final prefs = await pumpSafeLinkApp(tester, expert: false);
    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('Mode expert'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('expert_mode'), isTrue);
    await tapDestination(tester, 'Accueil');
    await history.analyzeLink(tester, lookalike);
    expect(find.text('Confiance : élevée'), findsOneWidget);
    expect(find.text('Indice fort'), findsWidgets);
    await flow.scrollTo(tester, find.text('Détails techniques'));
  });
}
