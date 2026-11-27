import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/rdap_bootstrap.g.dart';
import 'package:safelink/features/online/transports.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_online.dart';

final now = DateTime.utc(2026, 11, 27, 9);

OnlineLookupTarget targetOf(String url) =>
    OnlineLookupTarget.of(UrlParser().parse(url) as ParsedUrl)!;

ProviderStatus statusOf(OnlineEvidence evidence, ReputationSource source) =>
    evidence.reputation
        .firstWhere((r) => r.providerId == source.providerId)
        .status;

/// Transport qui ne répond jamais.
final class SilentTransport implements DohTransport, JsonTransport {
  @override
  Future<Uint8List> send(Uri endpoint, Uint8List message) =>
      Completer<Uint8List>().future;

  @override
  Future<Map<String, Object?>?> get(Uri uri) =>
      Completer<Map<String, Object?>?>().future;
}

void main() {
  group('consultations', () {
    test('site connu et ancien : non signalé, existe, date trouvée', () async {
      final dns = FakeDohTransport();
      final json = FakeJsonTransport(
        registeredOn: {'example.com': DateTime.utc(1995, 8, 14)},
      );
      final evidence = await fakeChecker(
        dns: dns,
        json: json,
        clock: () => now,
      ).check(targetOf('https://www.example.com/chemin?token=secret'));

      for (final source in ReputationSource.values) {
        expect(statusOf(evidence, source), ProviderStatus.noMatch);
      }
      expect(evidence.reputation.first.isFreshWithin(Duration.zero), isTrue);
      expect(evidence.resolution!.status, LookupStatus.found);
      expect(evidence.registration!.registeredAt, DateTime.utc(1995, 8, 14));

      // Seul le nom du site part vers les résolveurs ; seul le domaine
      // enregistré part vers le registre.
      expect(dns.sentNames.toSet(), {'www.example.com'});
      expect(dns.endpoints.toSet(), {
        'cloudflare-dns.com',
        'dns.quad9.net',
        'security.cloudflare-dns.com',
      });
      expect(
        json.requested.single.toString(),
        'https://rdap.verisign.com/com/v1/domain/example.com',
      );
    });

    test('bloqué par Quad9 seulement', () async {
      final evidence = await fakeChecker(
        dns: FakeDohTransport(blockedByQuad9: {'arnaque.example.com'}),
      ).check(targetOf('https://arnaque.example.com/'));
      expect(statusOf(evidence, ReputationSource.quad9), ProviderStatus.match);
      expect(
        statusOf(evidence, ReputationSource.cloudflare),
        ProviderStatus.noMatch,
      );
    });

    test('bloqué par Cloudflare seulement', () async {
      final evidence = await fakeChecker(
        dns: FakeDohTransport(blockedByCloudflare: {'virus.example.com'}),
      ).check(targetOf('https://virus.example.com/'));
      expect(
        statusOf(evidence, ReputationSource.cloudflare),
        ProviderStatus.match,
      );
      expect(
        evidence.reputation
            .firstWhere(
              (r) => r.isConclusive && r.status == ProviderStatus.match,
            )
            .matches
            .single
            .threatType,
        ThreatType.other,
      );
    });

    test('nom inexistant et inconnu du registre', () async {
      final evidence = await fakeChecker(
        dns: FakeDohTransport(missing: {'disparu.example.com'}),
      ).check(targetOf('https://disparu.example.com/'));
      expect(evidence.resolution!.status, LookupStatus.notFound);
      expect(evidence.registration!.status, LookupStatus.notFound);
      expect(
        statusOf(evidence, ReputationSource.quad9),
        ProviderStatus.noMatch,
      );
    });

    test('extension sans serveur RDAP (.bf) : date indisponible', () async {
      expect(rdapServers['bf'], isNull);
      final json = FakeJsonTransport();
      final evidence = await fakeChecker(json: json)
          .check(targetOf('https://www.lefaso.bf/'));
      expect(evidence.registration!.status, LookupStatus.unavailable);
      expect(json.requested, isEmpty);
    });

    test('sans connexion : tout indisponible, rien de mis en cache', () async {
      final checker = offlineChecker();
      final target = targetOf('https://example.com/');
      final evidence = await checker.check(target);
      expect(
        evidence.reputation.map((r) => r.status),
        everyElement(ProviderStatus.unavailable),
      );
      expect(evidence.resolution!.status, LookupStatus.unavailable);
      expect(evidence.registration!.status, LookupStatus.unavailable);
    });

    test('délai global dépassé : indisponible', () async {
      final silent = SilentTransport();
      final evidence = await OnlineChecker(
        dns: silent,
        json: silent,
        budget: const Duration(milliseconds: 50),
      ).check(targetOf('https://example.com/'));
      expect(evidence.resolution!.status, LookupStatus.unavailable);
      expect(
        evidence.reputation.map((r) => r.status),
        everyElement(ProviderStatus.unavailable),
      );
    });

    test('réponse complète gardée en mémoire pour la session', () async {
      final dns = FakeDohTransport();
      final checker = fakeChecker(dns: dns);
      final target = targetOf('https://example.com/');
      final first = await checker.check(target);
      final count = dns.sentNames.length;
      expect(await checker.check(target), same(first));
      expect(dns.sentNames, hasLength(count));
    });

    test('date d’enregistrement RDAP', () {
      expect(
        OnlineChecker.registrationDate({
          'events': [
            {
              'eventAction': 'last changed',
              'eventDate': '2024-01-01T00:00:00Z',
            },
            {
              'eventAction': 'registration',
              'eventDate': '2003-08-25T08:40:08Z',
            },
          ],
        }),
        DateTime.utc(2003, 8, 25, 8, 40, 8),
      );
      expect(OnlineChecker.registrationDate({'events': 'x'}), isNull);
      expect(OnlineChecker.registrationDate(const {}), isNull);
      expect(
        OnlineChecker.registrationDate({
          'events': [
            {'eventAction': 'registration', 'eventDate': 'pas une date'},
          ],
        }),
        isNull,
      );
    });

    test('table RDAP embarquée : https seulement', () {
      expect(rdapServers.length, greaterThan(1000));
      expect(rdapServers.values, everyElement(startsWith('https://')));
      expect(rdapServers.values, everyElement(endsWith('/')));
      expect(rdapServers['com'], 'https://rdap.verisign.com/com/v1/');
      expect(rdapBootstrapPublished, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('sources : identifiants stables', () {
      expect(ReputationSource.byProviderId('QUAD9'), ReputationSource.quad9);
      expect(ReputationSource.byProviderId('AUTRE'), isNull);
      for (final source in ReputationSource.values) {
        expect(source.endpoint, startsWith('https://'));
      }
    });
  });

  group('analyse avec vérification en ligne', () {
    DeviceAnalysisService service(OnlineChecker checker) =>
        DeviceAnalysisService(checker: checker, useIsolates: false);

    final clean = fakeChecker(
      json: FakeJsonTransport(
        registeredOn: {'lefaso.net': DateTime.utc(2003, 8, 25)},
      ),
    );

    test('site ancien non signalé : aucun danger connu', () async {
      final stages = <AnalysisStage>[];
      final outcome = await service(clean).analyze(
        AnalysisRequest(AnalysisKind.link, 'https://lefaso.net/'),
        online: true,
        onStage: stages.add,
      ) as LinkOutcome;
      expect(outcome.online, OnlineStatus.done);
      expect(outcome.result.verdict, UrlVerdict.noKnownThreat);
      expect(stages, [AnalysisStage.online]);
    });

    test('sans accord : rien n’est consulté', () async {
      final dns = FakeDohTransport();
      final outcome = await service(fakeChecker(dns: dns))
          .analyze(AnalysisRequest(AnalysisKind.link, 'https://lefaso.net/'));
      expect(outcome.online, OnlineStatus.notRequested);
      expect(dns.sentNames, isEmpty);
      expect((outcome as LinkOutcome).result.verdict, UrlVerdict.inconclusive);
    });

    test('adresse IP : rien à consulter', () async {
      final outcome = await service(clean).analyze(
        AnalysisRequest(AnalysisKind.link, 'http://192.168.1.1/'),
        online: true,
      );
      expect(outcome.online, OnlineStatus.notApplicable);
    });

    test('hors ligne : résultat local, état « sans réponse »', () async {
      final outcome = await service(offlineChecker()).analyze(
        AnalysisRequest(AnalysisKind.link, 'https://lefaso.net/'),
        online: true,
      ) as LinkOutcome;
      expect(outcome.online, OnlineStatus.unreachable);
      expect(outcome.result.verdict, UrlVerdict.inconclusive);
      expect(outcome.result.processing, Processing.localOnly);
    });

    test('message : chaque lien vérifié, une seule fois par site', () async {
      final dns = FakeDohTransport(blockedByQuad9: {'piege.example.com'});
      final outcome = await service(fakeChecker(dns: dns)).analyze(
        AnalysisRequest(
          AnalysisKind.message,
          'Voici https://piege.example.com/a et https://piege.example.com/b '
          'et https://lefaso.net/',
        ),
        online: true,
      ) as MessageOutcome;
      expect(outcome.online, OnlineStatus.done);
      expect(outcome.result.level, RiskLevel.danger);
      expect(outcome.result.links.map((l) => l.result.verdict), [
        UrlVerdict.knownThreat,
        UrlVerdict.knownThreat,
        isNot(UrlVerdict.knownThreat),
      ]);
      // 2 sites, 3 résolveurs chacun.
      expect(dns.sentNames, hasLength(6));
      // Le texte du message n'est jamais envoyé.
      expect(dns.sentNames.any((n) => n.contains('Voici')), isFalse);
    });

    test('dans de vrais isolats', () async {
      final outcome = await DeviceAnalysisService(checker: clean).analyze(
        AnalysisRequest(AnalysisKind.link, 'https://lefaso.net/'),
        online: true,
      ) as LinkOutcome;
      expect(outcome.result.verdict, UrlVerdict.noKnownThreat);
    });
  });
}
