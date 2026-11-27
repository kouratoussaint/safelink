import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/transports.dart';

import '../helpers/fake_online.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;
import 'history_flow_test.dart' as history;

/// Résolveurs qui attendent qu'on les libère.
final class GatedDohTransport implements DohTransport {
  final gate = Completer<void>();
  final inner = FakeDohTransport();

  @override
  Future<Uint8List> send(Uri endpoint, Uint8List message) async {
    await gate.future;
    return await inner.send(endpoint, message);
  }
}

OnlineChecker cleanChecker() => fakeChecker(
  json: FakeJsonTransport(
    registeredOn: {'lefaso.net': DateTime.utc(2003, 8, 25)},
  ),
);

void main() {
  group('lien vérifié en ligne', () {
    testWidgets('site ancien non signalé : aucun danger connu, détail', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: cleanChecker(),
      );
      await history.analyzeLink(tester, 'https://lefaso.net/actualites');

      expect(find.text('Aucun danger connu détecté'), findsOneWidget);
      expect(
        find.text('Cela ne garantit pas que le lien soit sûr.'),
        findsOneWidget,
      );
      await flow.scrollTo(tester, find.text('Vérifications en ligne'));
      expect(find.text('Quad9'), findsOneWidget);
      expect(find.text('Cloudflare'), findsOneWidget);
      expect(find.text('Non signalé'), findsNWidgets(2));
      await flow.scrollTo(tester, find.text('Création du domaine'));
      expect(find.textContaining('25 août 2003'), findsOneWidget);
      expect(find.textContaining('il y a 23 ans'), findsOneWidget);
      expect(find.text('Le nom existe'), findsOneWidget);
      expect(
        find.text(
          'Seul le nom « lefaso.net » a été envoyé, de façon chiffrée.',
        ),
        findsOneWidget,
      );
      await flow.scrollTo(tester, find.text('Ce qui a été vérifié'));
      await flow.scrollTo(tester, find.text('Connexion chiffrée (https)'));
      await flow.scrollTo(
        tester,
        find.text('Absent des listes de sites malveillants consultées'),
      );
      await flow.scrollTo(tester, find.text('Domaine qui n’est pas récent'));
    });

    testWidgets('signalé par Quad9 : menace connue', (tester) async {
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: fakeChecker(
          dns: FakeDohTransport(blockedByQuad9: {'piege.example.com'}),
        ),
      );
      await history.analyzeLink(tester, 'https://piege.example.com/');
      expect(find.text('Menace connue détectée'), findsOneWidget);
      expect(
        find.textContaining('signalé comme site malveillant'),
        findsOneWidget,
      );
      await flow.scrollTo(tester, find.text('Signalé comme malveillant'));
    });

    testWidgets('domaine créé avant-hier : lien suspect', (tester) async {
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: fakeChecker(
          json: FakeJsonTransport(
            registeredOn: {
              'promo-neuve.com': DateTime.now().toUtc().subtract(
                const Duration(days: 2, hours: 1),
              ),
            },
          ),
        ),
      );
      await history.analyzeLink(tester, 'https://promo-neuve.com/');
      expect(find.text('Lien suspect'), findsOneWidget);
      expect(find.textContaining('(il y a 2 jours)'), findsWidgets);
    });

    testWidgets('pas de connexion : résultat local et « Réessayer »', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester, online: OnlineChoice.enabled);
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(find.text('Analyse insuffisante'), findsOneWidget);
      await flow.scrollTo(
        tester,
        find.text('Aucun service n’a répondu : vérifiez votre connexion.'),
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('étape affichée pendant la vérification en ligne', (
      tester,
    ) async {
      final dns = GatedDohTransport();
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: OnlineChecker(dns: dns, json: FakeJsonTransport()),
      );
      await flow.enterText(tester, 'https://lefaso.net/');
      await tester.tap(flow.button('Analyser le lien'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Vérification en ligne…'), findsOneWidget);
      expect(
        find.text('Seul le nom du site est envoyé, de façon chiffrée.'),
        findsOneWidget,
      );
      dns.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Aucun danger connu détecté'), findsOneWidget);
    });
  });

  group('consentement', () {
    testWidgets('par défaut : vérifié en ligne sans rien demander', (
      tester,
    ) async {
      final prefs = await pumpSafeLinkApp(
        tester,
        online: null,
        onlineChecker: cleanChecker(),
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(find.text('Aucun danger connu détecté'), findsOneWidget);
      expect(prefs.getString(OnlineChoiceController.storageKey), isNull);
    });

    testWidgets('désactivée : rien n’est envoyé, réactivable', (tester) async {
      final dns = FakeDohTransport();
      await pumpSafeLinkApp(tester, onlineChecker: fakeChecker(dns: dns));
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(dns.sentNames, isEmpty);
      await flow.scrollTo(
        tester,
        find.textContaining('Vérification en ligne désactivée'),
      );
      expect(find.text('Activer'), findsOneWidget);
    });

    testWidgets('désactivée : « Activer » relance avec vérification', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester, onlineChecker: cleanChecker());
      await history.analyzeLink(tester, 'https://lefaso.net/');
      await flow.scrollTo(tester, find.text('Activer'));
      await tester.tap(find.text('Activer'));
      await tester.pumpAndSettle();
      expect(find.text('Non signalé'), findsNWidgets(2));
      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 3000),
        5000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Aucun danger connu détecté'), findsOneWidget);
    });

    testWidgets('interrupteur des paramètres', (tester) async {
      final prefs = await pumpSafeLinkApp(tester);
      await tapDestination(tester, 'Paramètres');
      await tester.tap(find.text('Vérifier les liens en ligne'));
      await tester.pumpAndSettle();
      expect(prefs.getString(OnlineChoiceController.storageKey), 'enabled');
      await tester.tap(find.text('Vérifier les liens en ligne'));
      await tester.pumpAndSettle();
      expect(prefs.getString(OnlineChoiceController.storageKey), 'disabled');
    });
  });

  group('message', () {
    testWidgets('liens vérifiés, détail d’un lien, liste du texte', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: fakeChecker(
          dns: FakeDohTransport(blockedByCloudflare: {'photos-fete.com'}),
        ),
      );
      await history.analyzeMessage(
        tester,
        'Salut, voici les photos de la fête : https://photos-fete.com/a',
      );
      expect(find.text('Synthèse : Danger'), findsOneWidget);
      await flow.scrollTo(tester, find.text('https://photos-fete.com/a'));
      expect(
        find.text(
          'Liens vérifiés en ligne : ouvrez un lien pour voir le détail.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('https://photos-fete.com/a'));
      await tester.pumpAndSettle();
      expect(find.text('Résultat du lien'), findsOneWidget);
      expect(find.text('Menace connue détectée'), findsOneWidget);
      await flow.scrollTo(tester, find.text('Signalé comme malveillant'));

      await flow.pressBack(tester);
      await flow.scrollTo(
        tester,
        find.text('Pas de demande de paiement ou de frais'),
      );
    });
  });

  testWidgets('historique : une vérification en ligne remplace l’entrée', (
    tester,
  ) async {
    final backend = MemoryHistoryBackend();
    await pumpSafeLinkApp(
      tester,
      onlineChecker: cleanChecker(),
      preferences: history.enabled,
      historyBackend: backend,
    );
    await history.analyzeLink(tester, 'https://lefaso.net/');
    expect((await backend.entries()).single.verdictCode, 'INCONCLUSIVE');
    await flow.scrollTo(tester, find.text('Activer'));
    await tester.tap(flow.button('Activer'));
    await tester.pumpAndSettle();
    final entries = await backend.entries();
    expect(entries, hasLength(1));
    expect(entries.single.verdictCode, 'NO_KNOWN_THREAT');
  });
}
