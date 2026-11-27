import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 9);
  final context = AnalysisContext(clock: () => now);
  final analyzer = UrlAnalyzer();
  const clean = 'https://lefaso.net/actualites';

  ProviderResult provider(
    ProviderStatus status, {
    Duration age = Duration.zero,
    ThreatType type = ThreatType.phishing,
    String id = 'QUAD9',
  }) => ProviderResult(
    providerId: id,
    status: status,
    checkedAt: now,
    feedUpdatedAt: now.subtract(age),
    matches: status == ProviderStatus.match
        ? [ThreatMatch(threatType: type)]
        : const [],
  );

  DomainRegistration registeredDaysAgo(int days) => DomainRegistration.found(
    registeredAt: now.subtract(Duration(days: days)),
    checkedAt: now,
  );

  UrlAnalysisResult analyze(String url, OnlineEvidence evidence) =>
      analyzer.analyzeOnline(url, context, evidence);

  List<String> codes(UrlAnalysisResult result) =>
      result.signals.map((s) => s.code).toList();

  group('réputation', () {
    test('signalé récemment : indice fort et menace connue', () {
      final result = analyze(
        clean,
        OnlineEvidence(reputation: [provider(ProviderStatus.match)]),
      );
      expect(result.verdict, UrlVerdict.knownThreat);
      final signal = result.signals.first;
      expect(signal.code, UrlSignalCodes.reported);
      expect(signal.severity, Severity.high);
      expect(signal.source, SignalSource.threatIntel);
      expect(signal.reason, contains('hameçonnage'));
      expect(signal.evidence, 'lefaso.net');
    });

    test('libellé selon le type de menace et le nombre de sources', () {
      final malware = analyze(
        clean,
        OnlineEvidence(
          reputation: [
            provider(ProviderStatus.match, type: ThreatType.malware),
          ],
        ),
      );
      expect(malware.signals.first.reason, contains('logiciels malveillants'));
      final two = analyze(
        clean,
        OnlineEvidence(
          reputation: [
            provider(ProviderStatus.match, type: ThreatType.other),
            provider(ProviderStatus.match, id: 'CLOUDFLARE'),
          ],
        ),
      );
      expect(two.signals.first.reason, contains('par 2 sources'));
      expect(two.signals.first.reason, contains('site malveillant'));
    });

    test('signalement ancien : pas d’indice en ligne, lien suspect', () {
      final result = analyze(
        clean,
        OnlineEvidence(
          reputation: [
            provider(ProviderStatus.match, age: const Duration(days: 30)),
          ],
        ),
      );
      expect(codes(result), isNot(contains(UrlSignalCodes.reported)));
      expect(result.verdict, UrlVerdict.suspicious);
    });

    test('consultée sans correspondance : aucun danger connu', () {
      final result = analyze(
        clean,
        OnlineEvidence(reputation: [provider(ProviderStatus.noMatch)]),
      );
      expect(result.verdict, UrlVerdict.noKnownThreat);
      final limits = result.limitations.map((l) => l.code);
      expect(limits, contains('REPUTATION_DOMAIN_LEVEL'));
      expect(limits, isNot(contains('REPUTATION_UNAVAILABLE')));
      expect(limits, contains('PAGE_NOT_OPENED'));
      expect(result.processing, Processing.localAndNetwork);
      expect(
        result.privacyImpact,
        PrivacyImpact.providerContactedWithoutContent,
      );
    });

    test('jamais rassurant quand la page réelle est cachée', () {
      for (final url in [
        'https://bit.ly/3exemple',
        'https://docs.google.com/forms/d/e/exemple/viewform',
        'https://lefaso.net/sortie?url=https://autre.example/',
      ]) {
        final result = analyze(
          url,
          OnlineEvidence(reputation: [provider(ProviderStatus.noMatch)]),
        );
        expect(result.verdict, UrlVerdict.inconclusive, reason: url);
      }
    });

    test('un indice moyen empêche « aucun danger connu »', () {
      final result = analyze(
        'https://exemple-bonus.bf/',
        OnlineEvidence(reputation: [provider(ProviderStatus.noMatch)]),
      );
      expect(
        result.signals.where((s) => s.severity == Severity.medium),
        hasLength(1),
      );
      expect(result.verdict, UrlVerdict.inconclusive);
    });

    test('sans consultation : analyse locale, rien n’a quitté l’appareil', () {
      final result = analyze(clean, OnlineEvidence.none);
      expect(result.verdict, UrlVerdict.inconclusive);
      expect(result.processing, Processing.localOnly);
      expect(result.privacyImpact, PrivacyImpact.stayedOnDevice);
      expect(
        result.limitations.map((l) => l.code),
        contains('REPUTATION_UNAVAILABLE'),
      );
    });
  });

  group('âge du domaine', () {
    test('moins de 7 jours : indice fort, lien suspect', () {
      final result = analyze(
        clean,
        OnlineEvidence(
          reputation: [provider(ProviderStatus.noMatch)],
          registration: registeredDaysAgo(2),
        ),
      );
      final signal = result.signals.single;
      expect(signal.code, UrlSignalCodes.domainNew);
      expect(signal.severity, Severity.high);
      expect(signal.reason, contains('le 25/11/2026 (il y a 2 jours)'));
      expect(signal.source, SignalSource.onlineLookup);
      expect(result.verdict, UrlVerdict.suspicious);
      expect(result.registration, registeredDaysAgo(2));
    });

    test('aujourd’hui, hier', () {
      expect(
        analyze(
          clean,
          OnlineEvidence(registration: registeredDaysAgo(0)),
        ).signals.single.reason,
        contains('(aujourd’hui)'),
      );
      expect(
        analyze(
          clean,
          OnlineEvidence(registration: registeredDaysAgo(1)),
        ).signals.single.reason,
        contains('(hier)'),
      );
    });

    test('moins de 30 jours : moyen ; moins de 90 : faible ; sinon rien', () {
      Severity? severityAt(int days) => analyze(
        clean,
        OnlineEvidence(registration: registeredDaysAgo(days)),
      ).signals.firstOrNull?.severity;
      expect(severityAt(20), Severity.medium);
      expect(severityAt(60), Severity.low);
      expect(severityAt(400), isNull);
    });

    test('jamais pour le domaine officiel d’une marque', () {
      final result = analyze(
        'https://www.orange.bf/',
        OnlineEvidence(registration: registeredDaysAgo(2)),
      );
      expect(codes(result), isNot(contains(UrlSignalCodes.domainNew)));
    });

    test('date future (horloge décalée) : comptée comme aujourd’hui', () {
      final result = analyze(
        clean,
        OnlineEvidence(
          registration: DomainRegistration.found(
            registeredAt: now.add(const Duration(hours: 3)),
            checkedAt: now,
          ),
        ),
      );
      expect(result.signals.single.severity, Severity.high);
    });

    test('registre sans réponse ou domaine inconnu du registre : rien', () {
      for (final registration in [
        DomainRegistration.unavailable(checkedAt: now),
        DomainRegistration.notFound(checkedAt: now),
      ]) {
        expect(
          analyze(clean, OnlineEvidence(registration: registration)).signals,
          isEmpty,
        );
      }
    });
  });

  group('existence du nom', () {
    test('nom inexistant : indice faible, jamais rassurant', () {
      final result = analyze(
        clean,
        OnlineEvidence(
          reputation: [provider(ProviderStatus.noMatch)],
          resolution: DomainResolution(
            status: LookupStatus.notFound,
            checkedAt: now,
          ),
        ),
      );
      expect(codes(result), [UrlSignalCodes.domainNotFound]);
      expect(result.signals.single.severity, Severity.low);
      expect(result.verdict, UrlVerdict.inconclusive);
    });

    test('nom existant : rien', () {
      final result = analyze(
        clean,
        OnlineEvidence(
          resolution: DomainResolution(
            status: LookupStatus.found,
            checkedAt: now,
          ),
        ),
      );
      expect(result.signals, isEmpty);
      expect(result.processing, Processing.localAndNetwork);
    });
  });

  group('cible des consultations', () {
    OnlineLookupTarget? targetOf(String url) =>
        OnlineLookupTarget.of(UrlParser().parse(url) as ParsedUrl);

    test('nom du site et domaine enregistré, jamais le chemin', () {
      final target = targetOf('https://www.lefaso.net/a/b?token=secret')!;
      expect(target.host, 'www.lefaso.net');
      expect(target.domain, 'lefaso.net');
      expect(target.toString(), isNot(contains('lefaso')));
      expect(
        target,
        const OnlineLookupTarget(host: 'www.lefaso.net', domain: 'lefaso.net'),
      );
    });

    test('nom international : forme ASCII', () {
      expect(
        targetOf('https://café.example.com/')!.host,
        'xn--caf-dma.example.com',
      );
    });

    test('rien à consulter : IP, nom sans extension, extension inconnue', () {
      for (final url in [
        'http://192.168.1.1/',
        'http://[2001:db8::1]/',
        'http://intranet/',
        'https://exemple.inconnu-xyz/',
      ]) {
        expect(targetOf(url), isNull, reason: url);
      }
    });
  });

  group('validation', () {
    test('dates en UTC obligatoires', () {
      expect(
        () => DomainRegistration.found(
          registeredAt: DateTime(2026),
          checkedAt: now,
        ),
        throwsArgumentError,
      );
      expect(
        () => DomainResolution(
          status: LookupStatus.found,
          checkedAt: DateTime(2026),
        ),
        throwsArgumentError,
      );
    });

    test('égalité et âge', () {
      expect(registeredDaysAgo(3).age, const Duration(days: 3));
      expect(DomainRegistration.notFound(checkedAt: now).age, isNull);
      expect(
        DomainResolution(status: LookupStatus.notFound, checkedAt: now),
        DomainResolution(status: LookupStatus.notFound, checkedAt: now),
      );
      expect(OnlineEvidence.none.isEmpty, isTrue);
      expect(
        OnlineEvidence(registration: registeredDaysAgo(3)).isEmpty,
        isFalse,
      );
    });
  });

  test('message : éléments en ligne par lien', () {
    final result = CombinedAnalyzer().analyze(
      'Regarde ça : https://photos-fete.example/a et https://lefaso.net/',
      context,
      online: (link) => link.url.contains('photos-fete')
          ? OnlineEvidence(reputation: [provider(ProviderStatus.match)])
          : null,
    );
    expect(result.links.first.result.verdict, UrlVerdict.knownThreat);
    expect(result.links.last.result.verdict, UrlVerdict.inconclusive);
    expect(result.level, RiskLevel.danger);
    expect(
      CombinedAnalyzer().linksToAnalyze(
        'a https://a.example/ b https://b.example/',
        context,
      ),
      hasLength(2),
    );
  });
}
