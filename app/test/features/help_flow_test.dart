import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/router.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/transports.dart';

import '../helpers/fake_online.dart';
import '../helpers/fake_speaker.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;
import 'history_flow_test.dart' as history;

/// Service qui ne répond jamais.
final class _SilentDoh implements DohTransport {
  @override
  Future<Uint8List> send(Uri endpoint, Uint8List message) =>
      Completer<Uint8List>().future;
}

final class _SilentJson implements JsonTransport {
  @override
  Future<Map<String, Object?>?> get(Uri uri) =>
      Completer<Map<String, Object?>?>().future;
}

/// Va directement à [location], comme un lien profond.
Future<void> goTo(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

Future<void> openTips(WidgetTester tester) async {
  await tapDestination(tester, 'Conseils');
}

void main() {
  group('fiches de prévention', () {
    testWidgets('toutes les fiches, la fiche d’urgence en tête', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester, expert: false);
      await openTips(tester);
      expect(find.text('Déjà piégé ? Que faire'), findsOneWidget);
      for (final title in [
        'Codes secrets',
        'Faux transfert « par erreur »',
        'Codes à composer',
        'Faux agents au téléphone',
        'Applications hors Play Store',
        'Gains et loteries',
        'Faux emplois et sélections',
        'Liens et faux sites',
        'QR codes',
        'Messages qui pressent',
      ]) {
        await flow.scrollTo(tester, find.text(title));
      }
    });

    testWidgets('fiche : piège, signes, que faire, « Écouter »', (
      tester,
    ) async {
      final speaker = FakeSpeaker();
      await pumpSafeLinkApp(tester, expert: false, speaker: speaker);
      await openTips(tester);
      await flow.scrollTo(tester, find.text('Codes secrets'));
      await tester.tap(find.text('Codes secrets'));
      await tester.pumpAndSettle();
      expect(find.text('Le piège'), findsOneWidget);
      await tester.tap(flow.button('Écouter'));
      await tester.pumpAndSettle();
      expect(speaker.spoken.single, startsWith('Codes secrets.'));
      expect(speaker.spoken.single, contains('Que faire.'));
      await flow.scrollTo(
        tester,
        find.text('Ne donnez jamais votre code, à personne'),
      );
      await flow.scrollTo(tester, find.text('Vérifier un lien ou un message'));
      await tester.tap(flow.button('Vérifier un lien ou un message'));
      await tester.pumpAndSettle();
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });

    testWidgets('urgence : signaler sur Alerte-BCLCC', (tester) async {
      await pumpSafeLinkApp(tester, expert: false);
      await openTips(tester);
      await tester.tap(find.text('Déjà piégé ? Que faire'));
      await tester.pumpAndSettle();
      expect(find.text('Tout de suite'), findsOneWidget);
      await flow.scrollTo(tester, find.textContaining('alerte.bclcc.gov.bf'));
      expect(find.text('Ensuite'), findsOneWidget);
    });

    testWidgets('fiche inconnue : message et retour aux fiches', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await goTo(tester, '/conseils/inconnue');
      expect(find.text('Fiche introuvable.'), findsOneWidget);
      await tester.tap(flow.button('Voir toutes les fiches'));
      await tester.pumpAndSettle();
      expect(find.text('Déjà piégé ? Que faire'), findsOneWidget);
    });
  });

  testWidgets('adresse inconnue : page en français, retour à l’accueil', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester);
    await goTo(tester, '/nulle-part');
    expect(find.text('Page introuvable'), findsWidgets);
    await tester.tap(flow.button('Revenir à l’accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Lien à vérifier'), findsOneWidget);
  });

  group('aide et exemples', () {
    testWidgets('aide : gestes, couleurs, limites', (tester) async {
      await pumpSafeLinkApp(tester, expert: false);
      await tester.tap(find.byTooltip('Aide'));
      await tester.pumpAndSettle();
      expect(find.text('Comment ça marche'), findsOneWidget);
      for (final word in [
        'Danger !',
        'Attention !',
        'Prudence',
        'Rien de suspect',
        'Illisible',
      ]) {
        await flow.scrollTo(tester, find.text(word));
      }
      await flow.scrollTo(
        tester,
        find.text('Ce que SafeLink ne peut pas faire'),
      );
    });

    testWidgets('exemple : analysé, signalé, jamais enregistré ni envoyé', (
      tester,
    ) async {
      final backend = MemoryHistoryBackend();
      final dns = FakeDohTransport();
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
        onlineChecker: fakeChecker(dns: dns),
        preferences: history.enabled,
        historyBackend: backend,
      );
      await flow.scrollTo(tester, find.text('Essayer avec un exemple'));
      await tester.tap(find.text('Essayer avec un exemple'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Exemples inventés'), findsOneWidget);
      await flow.scrollTo(
        tester,
        find.text('SMS : argent envoyé « par erreur »'),
      );
      await tester.tap(find.text('SMS : argent envoyé « par erreur »'));
      await tester.pumpAndSettle();
      expect(find.text('Danger !'), findsOneWidget);
      expect(find.textContaining('Exemple inventé'), findsOneWidget);
      expect(find.text('Garder vos vérifications ?'), findsNothing);
      expect(await backend.entries(), isEmpty);
      expect(dns.sentNames, isEmpty);
      // Retour : la liste des exemples.
      await flow.pressBack(tester);
      expect(appBarTitle('Exemples'), findsOneWidget);
    });

    testWidgets('exemple de lien : faux site repéré', (tester) async {
      await pumpSafeLinkApp(tester, expert: false);
      await goTo(tester, '/accueil/aide/exemples');
      await tester.tap(find.text('Lien vers un faux site'));
      await tester.pumpAndSettle();
      expect(find.text('Attention !'), findsOneWidget);
      expect(
        find.text('Ce lien ressemble à un piège. Ne l’ouvrez pas.'),
        findsOneWidget,
      );
    });
  });

  group('confidentialité', () {
    testWidgets('depuis les paramètres : ce qui reste, ce qui part', (
      tester,
    ) async {
      final prefs = await pumpSafeLinkApp(
        tester,
        online: null,
        googleKey: 'test-key',
      );
      await tapDestination(tester, 'Paramètres');
      await tester.scrollUntilVisible(find.text('Confidentialité'), 200);
      await tester.tap(find.text('Confidentialité'));
      await tester.pumpAndSettle();
      expect(
        find.text('Le texte de vos messages : jamais envoyé'),
        findsOneWidget,
      );
      await flow.scrollTo(
        tester,
        find.textContaining('Google : le lien, pour photographier la page'),
      );
      await flow.scrollTo(tester, find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.getString(OnlineChoiceController.storageKey), 'disabled');
    });

    testWidgets('sans clé Google : Google n’est pas cité', (tester) async {
      await pumpSafeLinkApp(tester);
      await goTo(tester, '/parametres/confidentialite');
      await flow.scrollTo(tester, find.textContaining('Quad9 et Cloudflare'));
      expect(find.textContaining('Google'), findsNothing);
    });
  });

  test('étape en ligne bornée : aucun blocage sans fin', () async {
    final service = DeviceAnalysisService(
      checker: OnlineChecker(
        dns: _SilentDoh(),
        json: _SilentJson(),
        budget: const Duration(hours: 1),
      ),
      useIsolates: false,
      onlineBudget: const Duration(milliseconds: 200),
    );
    final outcome = await service
        .analyze(
          AnalysisRequest(AnalysisKind.link, 'https://lefaso.net/'),
          online: true,
        )
        .timeout(const Duration(seconds: 5));
    expect(outcome.online, OnlineStatus.unreachable);
  });
}
