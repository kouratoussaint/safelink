import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_controller.dart';

import '../features/analysis_flow_test.dart' as flow;
import '../features/history_flow_test.dart' as history;
import '../features/online_flow_test.dart' as online;
import '../helpers/pump_app.dart';
import '../history/history_store_test.dart' show entryOf, secretUrl;

/// Ouvre l'écran voulu à partir de l'accueil.
typedef Navigate = Future<void> Function(WidgetTester tester);

final screens = <String, Navigate>{
  'Accueil': (tester) async {},
  'Historique': (tester) => tapDestination(tester, 'Historique'),
  'Conseils': (tester) => tapDestination(tester, 'Conseils'),
  'Paramètres': (tester) => tapDestination(tester, 'Paramètres'),
  'À propos': (tester) async {
    await openAbout(tester);
  },
  'Résultat d’un lien': (tester) async {
    await flow.enterText(tester, 'xn--pypal-4ve.com');
    await flow.analyze(tester, 'Analyser le lien');
  },
  'Résultat d’un message': (tester) async {
    await flow.selectMessageMode(tester);
    await flow.enterText(tester, flow.scamMessage);
    await flow.analyze(tester, 'Analyser le message');
  },
  'Résultat d’un lien du message': (tester) async {
    await flow.selectMessageMode(tester);
    await flow.enterText(tester, flow.scamMessage);
    await flow.analyze(tester, 'Analyser le message');
    final link = find.text('http://orange-gain.xyz/retrait');
    await flow.scrollTo(tester, link);
    await tester.tap(link);
    await tester.pumpAndSettle();
  },
};

void main() {
  for (final theme in ['light', 'dark']) {
    for (final expert in [false, true]) {
      final mode = expert ? 'expert' : 'simple';
      for (final MapEntry(key: name, value: navigate) in screens.entries) {
        testWidgets(
          '$name ($theme, $mode) respecte les règles d’accessibilité',
          (tester) async {
            final handle = tester.ensureSemantics();
            await pumpSafeLinkApp(
              tester,
              expert: expert,
              preferences: {ThemeModeController.storageKey: theme},
            );
            await navigate(tester);

            // Zones tactiles d'au moins 48 × 48 dp.
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            // Chaque élément interactif a un libellé lu par TalkBack.
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            // Contraste du texte affiché.
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            handle.dispose();
          },
        );
      }
    }
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('Présentation ($theme) respecte les règles d’accessibilité', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        onboarded: false,
        preferences: {ThemeModeController.storageKey: theme},
      );
      for (var step = 0; step < 4; step++) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        if (step < 3) {
          await tester.tap(find.text('Suivant'));
          await tester.pumpAndSettle();
        }
      }
      handle.dispose();
    });
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('Historique et fiche ($theme) respectent les règles', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final entry = entryOf(
        AnalysisKind.link,
        secretUrl,
      ).withContent(secretUrl);
      final backend = await history.filledBackend([
        entry,
        entryOf(AnalysisKind.message, flow.scamMessage),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: {
          ...history.enabled,
          ThemeModeController.storageKey: theme,
        },
        historyBackend: backend,
      );
      Future<void> check() async {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }

      await tapDestination(tester, 'Historique');
      await check();
      await tester.tap(find.text('secure-login.xyz'));
      await tester.pumpAndSettle();
      await check();
      handle.dispose();
    });

    testWidgets('Résultat avec proposition d’historique ($theme)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        preferences: {ThemeModeController.storageKey: theme},
      );
      await history.analyzeLink(tester, secretUrl);
      await flow.scrollTo(tester, find.text('Garder vos vérifications ?'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('Résultat vérifié en ligne ($theme)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: online.cleanChecker(),
        preferences: {ThemeModeController.storageKey: theme},
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      Future<void> check() async {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }

      await check();
      await flow.scrollTo(tester, find.text('Vérifications en ligne'));
      await check();
      await flow.scrollTo(tester, find.text('Ce qui a été vérifié'));
      await check();
      handle.dispose();
    });

    testWidgets('Bandeau « Pas de connexion » ($theme)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
        preferences: {ThemeModeController.storageKey: theme},
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      await flow.scrollTo(tester, find.text('Pas de connexion'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('le verdict est annoncé comme en-tête, avec son libellé', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSafeLinkApp(tester);
    await flow.enterText(tester, 'xn--pypal-4ve.com');
    await flow.analyze(tester, 'Analyser le lien');
    final node = tester.getSemantics(find.text('Lien suspect'));
    expect(node, isSemantics(isHeader: true));
    expect(node.label, startsWith('Lien suspect'));
    expect(node.label, contains('Confiance : élevée'));
    handle.dispose();
  });

  testWidgets('les titres de section sont annoncés comme en-têtes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSafeLinkApp(tester);
    await tapDestination(tester, 'Paramètres');
    expect(
      tester.getSemantics(find.text('Apparence')),
      matchesSemantics(label: 'Apparence', isHeader: true),
    );
    handle.dispose();
  });

  for (final (theme, asset) in [
    ('light', 'assets/brand/safelink_mark_on_light.svg'),
    ('dark', 'assets/brand/safelink_mark.svg'),
  ]) {
    testWidgets('le symbole adapté au thème $theme est affiché', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        preferences: {ThemeModeController.storageKey: theme},
      );
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      final loader = picture.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, asset);
    });
  }

  testWidgets('le logo a une description pour les lecteurs d’écran', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSafeLinkApp(tester);
    expect(
      find.bySemanticsLabel('Logo SafeLink : bouclier et maillon de chaîne'),
      findsWidgets,
    );
    expect(find.byType(AppBar), findsOneWidget);
    handle.dispose();
  });
}
