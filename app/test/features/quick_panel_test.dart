import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink/features/quick/quick_screen.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/features/results/verdict_hero.dart';
import 'package:safelink/features/share/shared_content.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_speaker.dart';
import '../helpers/pump_quick.dart';
import 'share_flow_test.dart' show twoLinks;

/// Lien piégé, copié dans une autre application.
const copiedLink = SharedText(
  'http://orange-gain.xyz/retrait',
  origin: ShareOrigin.clipboard,
);

/// Message d'arnaque sans lien, copié.
const copiedMessage = SharedText(
  'Félicitations ! Vous avez gagné 500 000 FCFA. Envoyez votre code '
  'secret Orange Money au 70 00 00 00.',
  origin: ShareOrigin.clipboard,
);

/// Fait défiler le panneau jusqu'à [finder].
Future<void> scrollPanelTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Fait défiler le panneau jusqu'au bout.
Future<void> scrollPanelToEnd(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

/// Appuie sur Retour.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Les écrans du panneau, pour les tests de mise en page et
/// d'accessibilité.
final quickScreens = <String, SharedContent?>{
  'Panneau : lecture': null,
  'Panneau : lien': copiedLink,
  'Panneau : message': copiedMessage,
  'Panneau : choix': const SharedText(twoLinks, origin: ShareOrigin.clipboard),
  'Panneau : rien de copié': const SharedNothing(origin: ShareOrigin.clipboard),
  'Panneau : texte secret': const SharedNothing(
    origin: ShareOrigin.clipboard,
    sensitive: true,
  ),
};

void main() {
  group('panneau rapide', () {
    testWidgets('un lien copié est vérifié tout de suite, en résumé', (
      tester,
    ) async {
      await pumpQuickPanel(tester, copied: copiedLink);

      expect(find.text('Vérification rapide'), findsOneWidget);
      expect(find.text('Attention !'), findsOneWidget);
      expect(find.text('Le vrai site'), findsOneWidget);
      expect(find.text('orange-gain.xyz'), findsOneWidget);
      expect(find.text('Mots pièges'), findsOneWidget);
      await scrollPanelTo(tester, find.text('Tout voir dans SafeLink'));
      expect(find.text('Ne touchez pas le lien'), findsOneWidget);
      // Pas les onglets de l'application, et jamais de quoi ouvrir le lien.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(ButtonStyleButton, 'Ouvrir'), findsNothing);
      final hero = tester.widget<VerdictHero>(find.byType(VerdictHero));
      expect(hero.compact, isTrue);
    });

    testWidgets('un message copié : au plus quatre raisons, trois gestes', (
      tester,
    ) async {
      await pumpQuickPanel(tester, copied: copiedMessage);

      expect(find.text('Danger !'), findsOneWidget);
      expect(find.text('Demande votre code'), findsOneWidget);
      await scrollPanelTo(tester, find.text('Tout voir dans SafeLink'));
      expect(find.text('Ne donnez jamais vos codes'), findsOneWidget);
    });

    testWidgets('texte et liens : choisir, puis voir le résultat', (
      tester,
    ) async {
      await pumpQuickPanel(
        tester,
        copied: const SharedText(twoLinks, origin: ShareOrigin.clipboard),
      );
      expect(find.text('Que voulez-vous vérifier ?'), findsOneWidget);

      await scrollPanelTo(tester, find.text('Le lien seulement'));
      await tester.tap(find.text('Le lien seulement'));
      await tester.pumpAndSettle();
      final choice = find.descendant(
        of: find.byType(HighlightedUrl),
        matching: find.textContaining('colis-bf.top'),
      );
      await scrollPanelTo(tester, choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();

      expect(find.text('Le vrai site'), findsOneWidget);
      expect(find.text('colis-bf.top'), findsOneWidget);
    });

    testWidgets('« Tout voir dans SafeLink » transmet la vérification', (
      tester,
    ) async {
      final quick = await pumpQuickPanel(tester, copied: copiedLink);
      await scrollPanelTo(tester, find.text('Tout voir dans SafeLink'));
      await tester.tap(find.text('Tout voir dans SafeLink'));
      await tester.pumpAndSettle();

      final (request, historyId) = quick.opened.single;
      expect(request.kind, AnalysisKind.link);
      expect(request.text, copiedLink.text);
      // Historique pas encore choisi : rien d'enregistré par le panneau.
      expect(historyId, isNull);
    });

    testWidgets('historique activé : enregistré, et le même identifiant '
        'est transmis', (tester) async {
      final history = MemoryHistoryBackend();
      final quick = await pumpQuickPanel(
        tester,
        copied: copiedLink,
        historyBackend: history,
        preferences: {
          HistoryChoiceController.storageKey: HistoryChoice.enabled.name,
        },
      );
      final saved = await history.entries();
      expect(saved, hasLength(1));
      expect(saved.single.level, RiskLevel.attention);
      // Ni le lien ni le texte ne sont gardés par défaut.
      expect(saved.single.content, isNull);

      await scrollPanelTo(tester, find.text('Tout voir dans SafeLink'));
      await tester.tap(find.text('Tout voir dans SafeLink'));
      await tester.pumpAndSettle();
      expect(quick.opened.single.$2, saved.single.id);
    });

    testWidgets('rien de copié : expliqué, « Fermer » ferme', (tester) async {
      final quick = await pumpQuickPanel(
        tester,
        copied: const SharedNothing(origin: ShareOrigin.clipboard),
      );
      expect(find.text('Rien à vérifier'), findsOneWidget);
      expect(find.textContaining('Rien n’est copié'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Fermer'));
      await tester.pumpAndSettle();
      expect(quick.closes, 1);
    });

    testWidgets('texte secret : jamais lu, dit simplement', (tester) async {
      await pumpQuickPanel(
        tester,
        copied: const SharedNothing(
          origin: ShareOrigin.clipboard,
          sensitive: true,
        ),
      );
      expect(find.textContaining('marqué secret'), findsOneWidget);
    });

    testWidgets('en attendant la lecture : un indicateur', (tester) async {
      await pumpQuickPanel(tester, settle: false);
      expect(find.text('Lecture du texte copié…'), findsOneWidget);
    });

    testWidgets('Retour ferme le panneau', (tester) async {
      final quick = await pumpQuickPanel(tester, copied: copiedLink);
      await pressBack(tester);
      expect(quick.closes, 1);
    });

    testWidgets('la croix ferme le panneau', (tester) async {
      final quick = await pumpQuickPanel(tester, copied: copiedLink);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(quick.closes, 1);
    });

    testWidgets('toucher à côté ferme le panneau, une seule fois', (
      tester,
    ) async {
      final quick = await pumpQuickPanel(
        tester,
        copied: const SharedNothing(origin: ShareOrigin.clipboard),
      );
      await tester.tapAt(const Offset(200, 20));
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(quick.closes, 1);
    });

    testWidgets('bulle touchée de nouveau : le nouveau texte remplace', (
      tester,
    ) async {
      final quick = await pumpQuickPanel(tester, copied: copiedLink);
      expect(find.text('orange-gain.xyz'), findsOneWidget);

      quick.send(
        const SharedText('https://example.com', origin: ShareOrigin.clipboard),
      );
      await tester.pumpAndSettle();
      expect(find.text('orange-gain.xyz'), findsNothing);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Prudence'), findsOneWidget);
    });

    testWidgets('« Écouter » lit le verdict résumé', (tester) async {
      final speaker = FakeSpeaker();
      await pumpQuickPanel(tester, copied: copiedLink, speaker: speaker);
      await tester.tap(find.text('Écouter'));
      await tester.pumpAndSettle();
      expect(speaker.spoken.single, startsWith('Attention'));
    });
  });

  group('raisons du panneau', () {
    RiskSignal signal(String code, Severity severity) => RiskSignal(
      code: 'SIG_$code',
      severity: severity,
      confidence: Confidence.medium,
      reason: code,
      source: SignalSource.urlHeuristic,
      detectedAt: DateTime.utc(2026, 11, 28),
    );

    test('les plus graves d’abord, quatre au plus, sans doublon', () {
      final reasons = mainReasons([
        signal('A', Severity.low),
        signal('B', Severity.high),
        signal('C', Severity.info),
        signal('D', Severity.medium),
        signal('B', Severity.high),
        signal('E', Severity.low),
        signal('F', Severity.high),
      ], expert: false);
      expect(reasons.map((s) => s.code), ['SIG_B', 'SIG_F', 'SIG_D', 'SIG_A']);
    });

    test('les simples informations seulement en mode expert', () {
      final signals = [signal('C', Severity.info)];
      expect(mainReasons(signals, expert: false), isEmpty);
      expect(mainReasons(signals, expert: true), hasLength(1));
    });
  });
}
