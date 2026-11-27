import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/pump_app.dart';
import '../history/history_store_test.dart' show entryOf, secretUrl;
import 'analysis_flow_test.dart' as flow;

const Map<String, Object> enabled = {
  HistoryChoiceController.storageKey: 'enabled',
};

Future<void> analyzeLink(WidgetTester tester, String url) async {
  await flow.enterText(tester, url);
  await flow.analyze(tester, 'Analyser le lien');
}

Future<void> analyzeMessage(WidgetTester tester, String text) async {
  await flow.selectMessageMode(tester);
  await flow.enterText(tester, text);
  await flow.analyze(tester, 'Analyser le message');
}

Future<void> tapText(WidgetTester tester, String text) async {
  await flow.scrollTo(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Historique pré-rempli.
Future<MemoryHistoryBackend> filledBackend(List<HistoryEntry> entries) async {
  final backend = MemoryHistoryBackend();
  final store = await backend.open();
  for (final entry in entries) {
    await store.add(entry);
  }
  return backend;
}

void main() {
  group('consentement', () {
    testWidgets('sans choix, rien n’est enregistré ni créé', (tester) async {
      final backend = MemoryHistoryBackend();
      await pumpSafeLinkApp(tester, historyBackend: backend);
      await analyzeLink(tester, secretUrl);

      await flow.scrollTo(tester, find.text('Garder vos vérifications ?'));
      expect(find.text('Activer l’historique'), findsOneWidget);
      expect(backend.openings, 0);
      expect(await backend.exists(), isFalse);
    });

    testWidgets('« Non merci » : choix retenu, toujours rien d’enregistré', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      final prefs = await pumpSafeLinkApp(tester, historyBackend: backend);
      await analyzeLink(tester, secretUrl);
      await tapText(tester, 'Non merci');

      expect(find.text('Garder vos vérifications ?'), findsNothing);
      expect(prefs.getString(HistoryChoiceController.storageKey), 'disabled');
      expect(backend.openings, 0);

      await flow.pressBack(tester);
      await analyzeLink(tester, 'https://example.com');
      expect(find.text('Garder vos vérifications ?'), findsNothing);
      expect(backend.openings, 0);
    });

    testWidgets('« Activer » enregistre aussi la vérification affichée', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      final prefs = await pumpSafeLinkApp(tester, historyBackend: backend);
      await analyzeLink(tester, secretUrl);
      await tapText(tester, 'Activer l’historique');

      expect(prefs.getString(HistoryChoiceController.storageKey), 'enabled');
      expect(
        find.text('Enregistrée dans l’historique, sans le lien complet.'),
        findsOneWidget,
      );
      final saved = (await backend.entries()).single;
      expect(saved.details!.domain, 'secure-login.xyz');
      expect(saved.content, isNull);
    });
  });

  group('enregistrement', () {
    testWidgets('lien : enregistré une seule fois, sans le lien complet', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await analyzeLink(tester, secretUrl);
      await flow.scrollTo(tester, find.text('Retirer'));
      await tester.pumpAndSettle();

      final entries = await backend.entries();
      expect(entries, hasLength(1));
      expect(entries.single.kind, AnalysisKind.link);
      expect(entries.single.content, isNull);
      expect(entries.single.details!.encode(), isNot(contains('token')));
    });

    testWidgets('message : ni texte ni extraits, liens résumés', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await analyzeMessage(tester, flow.scamMessage);

      final entry = (await backend.entries()).single;
      expect(entry.kind, AnalysisKind.message);
      expect(entry.level, RiskLevel.danger);
      expect(entry.content, isNull);
      expect(entry.details!.links.single.domain, 'orange-gain.xyz');
      final stored = entry.details!.encode();
      expect(stored, isNot(contains('Félicitations')));
      expect(stored, isNot(contains('500 000')));
      expect(stored, isNot(contains('70 00')));
    });

    testWidgets('texte intégral gardé seulement après avertissement', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await analyzeMessage(tester, flow.scamMessage);

      await tapText(tester, 'Garder aussi le texte du message');
      expect(find.text('Garder le texte du message ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect((await backend.entries()).single.content, isNull);

      await tapText(tester, 'Garder aussi le texte du message');
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();
      expect((await backend.entries()).single.content, flow.scamMessage);
      expect(
        find.text(
          'Enregistrée dans l’historique, avec le contenu complet chiffré.',
        ),
        findsOneWidget,
      );

      await tapText(tester, 'Ne plus le conserver');
      expect((await backend.entries()).single.content, isNull);
    });

    testWidgets('« Retirer » efface la vérification', (tester) async {
      final backend = MemoryHistoryBackend();
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await analyzeLink(tester, secretUrl);
      await tapText(tester, 'Retirer');
      expect(await backend.entries(), isEmpty);
      expect(find.text('Retirée de l’historique.'), findsOneWidget);
    });
  });

  group('écran Historique', () {
    testWidgets('liste groupée par jour, fiche puis suppression', (
      tester,
    ) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
        entryOf(AnalysisKind.message, flow.scamMessage),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');

      expect(find.text('Aujourd’hui'), findsWidgets);
      expect(find.text('secure-login.xyz'), findsOneWidget);
      expect(find.text('Message · 1 lien'), findsOneWidget);
      await flow.scrollTo(
        tester,
        find.textContaining('2 vérifications, chiffrées'),
      );

      await tapText(tester, 'secure-login.xyz');
      expect(appBarTitle('Vérification enregistrée'), findsOneWidget);
      expect(find.text('Lien suspect'), findsOneWidget);
      expect(find.text('Raisons enregistrées'), findsOneWidget);
      expect(find.text('Analyser à nouveau'), findsNothing);

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Historique'), findsOneWidget);
      expect(find.text('secure-login.xyz'), findsNothing);
      expect(await backend.entries(), hasLength(1));
    });

    testWidgets('filtres : nature, domaine, niveau', (tester) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
        entryOf(AnalysisKind.link, 'https://example.com'),
        entryOf(AnalysisKind.message, flow.scamMessage),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Message · 1 lien'), findsOneWidget);
      expect(find.text('example.com'), findsNothing);

      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'example');
      await tester.pumpAndSettle();
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('secure-login.xyz'), findsNothing);
      expect(find.text('Message · 1 lien'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Niveau et période'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Danger'));
      await tester.pumpAndSettle();
      expect(find.text('Message · 1 lien'), findsOneWidget);
      expect(find.text('example.com'), findsNothing);
      expect(find.text('1 filtre actif'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Danger'));
      await tester.tap(find.widgetWithText(FilterChip, 'Non analysable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucune vérification ne correspond à ces filtres.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Effacer les filtres'));
      await tester.pumpAndSettle();
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('« Tout effacer » après confirmation', (tester) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
        entryOf(AnalysisKind.link, 'https://example.com'),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');
      await tester.tap(find.byTooltip('Tout effacer'));
      await tester.pumpAndSettle();
      expect(find.text('Effacer tout l’historique ?'), findsOneWidget);
      expect(
        find.text(
          'Les 2 vérifications enregistrées seront supprimées de ce '
          'téléphone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tout effacer'));
      await tester.pumpAndSettle();
      expect(await backend.entries(), isEmpty);
      expect(find.text('Aucune vérification enregistrée'), findsOneWidget);
    });

    testWidgets('contenu conservé : lisible et réanalysable', (tester) async {
      final entry = entryOf(
        AnalysisKind.link,
        secretUrl,
      ).withContent(secretUrl);
      final backend = await filledBackend([entry]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');
      await tapText(tester, 'secure-login.xyz');
      await flow.scrollTo(tester, find.text(secretUrl));
      expect(find.text('Lien complet conservé'), findsOneWidget);

      await tapText(tester, 'Analyser à nouveau');
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.text('Lien suspect'), findsOneWidget);
    });

    testWidgets('vérification illisible : signalée et supprimable', (
      tester,
    ) async {
      final readable = entryOf(AnalysisKind.link, secretUrl);
      final backend = await filledBackend([
        HistoryEntry(
          id: readable.id,
          kind: readable.kind,
          level: readable.level,
          verdictCode: readable.verdictCode,
          analyzedAt: readable.analyzedAt,
          rulesVersion: readable.rulesVersion,
          signalCodes: readable.signalCodes,
          details: null,
        ),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');
      await tapText(tester, 'Vérification illisible');
      expect(
        find.textContaining('ne peut plus être déchiffré'),
        findsOneWidget,
      );
      expect(find.byTooltip('Supprimer'), findsOneWidget);
    });

    testWidgets('désactivé avec des vérifications : rappel et liste', (
      tester,
    ) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: {HistoryChoiceController.storageKey: 'disabled'},
        historyBackend: backend,
      );
      await tapDestination(tester, 'Historique');
      expect(find.text('Historique désactivé'), findsOneWidget);
      expect(find.text('secure-login.xyz'), findsOneWidget);
    });
  });

  group('paramètres', () {
    testWidgets('activer puis arrêter en effaçant', (tester) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
      ]);
      final prefs = await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Paramètres');
      await flow.scrollTo(tester, find.text('Enregistrer mes vérifications'));
      expect(find.text('1 vérification enregistrée'), findsOneWidget);

      await tester.tap(find.text('Enregistrer mes vérifications'));
      await tester.pumpAndSettle();
      expect(find.text('Arrêter l’historique ?'), findsOneWidget);
      await tester.tap(find.text('Arrêter et effacer'));
      await tester.pumpAndSettle();

      expect(prefs.getString(HistoryChoiceController.storageKey), 'disabled');
      expect(await backend.entries(), isEmpty);
      expect(find.text('Aucune vérification enregistrée'), findsOneWidget);

      await tester.tap(find.text('Enregistrer mes vérifications'));
      await tester.pumpAndSettle();
      expect(prefs.getString(HistoryChoiceController.storageKey), 'enabled');
    });

    testWidgets('arrêter seulement garde les vérifications', (tester) async {
      final backend = await filledBackend([
        entryOf(AnalysisKind.link, secretUrl),
      ]);
      await pumpSafeLinkApp(
        tester,
        preferences: enabled,
        historyBackend: backend,
      );
      await tapDestination(tester, 'Paramètres');
      await tapText(tester, 'Enregistrer mes vérifications');
      await tester.tap(find.text('Arrêter seulement'));
      await tester.pumpAndSettle();
      expect(await backend.entries(), hasLength(1));
    });
  });
}
