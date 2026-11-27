import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 12);
  final context = AnalysisContext(clock: () => now);
  final analyzer = UrlAnalyzer();

  ProviderResult provider(
    ProviderStatus status, {
    Duration age = const Duration(hours: 2),
  }) => ProviderResult(
    providerId: 'TEST_PROVIDER',
    status: status,
    checkedAt: now,
    feedUpdatedAt: now.subtract(age),
    matches: status == ProviderStatus.match
        ? [ThreatMatch(threatType: ThreatType.phishing)]
        : const [],
    errorCode: status == ProviderStatus.error ? 'TIMEOUT' : null,
  );

  group('résultat d’un lien lu', () {
    final result = analyzer.analyze(
      'https://www.paypal.com@evil-site.com/login?token=abcdef1234567890XYZ',
      context,
    );

    test('verdict, niveau et confiance', () {
      expect(result.verdict, UrlVerdict.suspicious);
      expect(result.level, RiskLevel.attention);
      expect(result.confidence, Confidence.high);
      expect(result.contentType, ContentType.url);
      expect(result.processing, Processing.localOnly);
      expect(result.privacyImpact, PrivacyImpact.stayedOnDevice);
      expect(result.analyzedAt, now);
      expect(result.failure, isNull);
      expect(result.url?.host, 'evil-site.com');
      expect(result.providerResults, isEmpty);
    });

    test('indices du plus grave au moins grave', () {
      final severities = result.signals.map((s) => s.severity.rank).toList();
      final sorted = [...severities]..sort((a, b) => b.compareTo(a));
      expect(severities, sorted);
      expect(result.signals.first.code, UrlSignalCodes.credentialsDeceptive);
      for (final signal in result.signals) {
        expect(signal.source, SignalSource.urlHeuristic);
        expect(signal.detectedAt, now);
      }
    });

    test('limites toujours affichées, jamais de promesse de sécurité', () {
      final codes = result.limitations.map((l) => l.code);
      expect(codes, containsAll(['PAGE_NOT_OPENED', 'REPUTATION_UNAVAILABLE']));
      final texts = [
        ...result.limitations.map((l) => l.description),
        ...result.recommendedActions.map((a) => a.description),
        ...result.signals.map((s) => s.reason),
      ].join(' ').toLowerCase();
      expect(texts, isNot(contains('100 %')));
      expect(texts, isNot(contains('sans danger')));
      expect(texts, isNot(matches(RegExp(r'\bsûr\b'))));
    });

    test('gestes recommandés', () {
      expect(
        result.recommendedActions.map((a) => a.code),
        containsAll(['DO_NOT_OPEN', 'NEVER_SHARE_CODES']),
      );
    });

    test('détails techniques, jeton masqué', () {
      final details = result.technicalDetails!;
      expect(
        details.displayUrl,
        'https://www.paypal.com@evil-site.com/login?token=•••',
      );
      expect(details.maskedValues, 1);
      expect(details.scheme, 'https');
      expect(details.host, 'evil-site.com');
      expect(details.hostUnicode, 'evil-site.com');
      expect(details.hostType, UrlHostType.domain);
      expect(details.port, isNull);
      expect(details.registrableDomain, 'evil-site.com');
      expect(details.publicSuffix, 'com');
      expect(details.isPrivateSuffix, isFalse);
      expect(details.scripts, {'Latin'});
      expect(details.normalizations, isEmpty);
      expect(details.brandMatches, isEmpty);
      for (final signal in result.signals) {
        expect(signal.evidence ?? '', isNot(contains('abcdef1234567890')));
      }
    });

    test('versions des règles et des données', () {
      expect(result.rulesVersion, analyzer.fullRulesVersion);
      expect(
        analyzer.fullRulesVersion,
        matches(
          RegExp(
            r'^url-\d+\.\d+\.\d+\+psl\.\d{4}-\d{2}-\d{2}'
            r'\+unicode\.\d+\.\d+\.\d+\+marques\.\d+$',
          ),
        ),
      );
      expect(analyzer.contentType, ContentType.url);
    });
  });

  group('détails techniques', () {
    test('nom international et hébergement partagé', () {
      final details = analyzer
          .analyze('http://xn--bcher-kva.blogspot.com:8080/', context)
          .technicalDetails!;
      expect(details.hostUnicode, 'bücher.blogspot.com');
      expect(details.port, 8080);
      expect(details.isPrivateSuffix, isTrue);
      expect(details.publicSuffix, 'blogspot.com');
      expect(details.scripts, {'Latin'});
    });

    test('adresse IP et nom sans extension', () {
      final ip = analyzer.analyze('http://10.0.0.1/', context);
      expect(ip.technicalDetails!.hostType, UrlHostType.ipv4);
      expect(ip.technicalDetails!.scripts, isEmpty);
      expect(ip.technicalDetails!.registrableDomain, isNull);
      expect(
        ip.signals.firstWhere((s) => s.code == UrlSignalCodes.ipLiteral).reason,
        contains('réseau local'),
      );
      final intranet = analyzer.analyze('https://intranet/', context);
      expect(intranet.technicalDetails!.scripts, {'Latin'});
    });

    test('lien sans protocole : limite affichée', () {
      final result = analyzer.analyze('example.com', context);
      expect(
        result.limitations.map((l) => l.code),
        contains('URL_SCHEME_ASSUMED'),
      );
      expect(result.technicalDetails!.normalizations, [
        UrlNormalization.schemeAdded,
      ]);
    });

    test('marque officielle : rapprochement visible, aucun indice', () {
      final result = analyzer.analyze('https://www.orange.bf/', context);
      expect(result.signals, isEmpty);
      expect(result.verdict, UrlVerdict.inconclusive);
      expect(
        result.technicalDetails!.brandMatches.single.kind,
        BrandMatchKind.official,
      );
    });
  });

  group('texte non analysable', () {
    test('schéma non web', () {
      final result = analyzer.analyze('javascript:alert(1)', context);
      expect(result.verdict, UrlVerdict.invalid);
      expect(result.level, RiskLevel.notAnalyzable);
      expect(result.confidence, Confidence.high);
      expect(result.url, isNull);
      expect(result.technicalDetails, isNull);
      expect(result.failure!.scheme, 'javascript');
      expect(result.signals, isEmpty);
      expect(result.limitations.single.code, 'URL_NOT_ANALYZED');
      expect(result.recommendedActions.map((a) => a.code), [
        'DO_NOT_OPEN',
        'VERIFY_OFFICIAL_CHANNEL',
      ]);
    });

    test('texte ordinaire', () {
      final result = analyzer.analyze('bonjour', context);
      expect(result.verdict, UrlVerdict.invalid);
      expect(result.recommendedActions.map((a) => a.code), [
        'VERIFY_OFFICIAL_CHANNEL',
      ]);
    });

    test('un résultat porte un lien ou un échec, pas les deux', () {
      expect(
        () => UrlAnalysisResult(
          verdict: UrlVerdict.invalid,
          confidence: Confidence.high,
          signals: const [],
          limitations: [Limitation(code: 'TEST_LIMIT', description: 'x')],
          recommendedActions: const [],
          analyzedAt: now,
          rulesVersion: 'test',
          providerResults: const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('verdict avec des sources de réputation', () {
    const benign = 'https://lefaso.net/';
    const suspicious = 'https://paypa1.com/';

    UrlVerdict verdictOf(String url, List<ProviderResult> results) =>
        analyzer.analyzeWithReputation(url, context, results).verdict;

    test('correspondance récente : KNOWN_THREAT', () {
      final result = analyzer.analyzeWithReputation(benign, context, [
        provider(ProviderStatus.match),
      ]);
      expect(result.verdict, UrlVerdict.knownThreat);
      expect(result.confidence, Confidence.high);
      expect(result.providerResults, hasLength(1));
      expect(
        result.limitations.map((l) => l.code),
        isNot(contains('REPUTATION_UNAVAILABLE')),
      );
      expect(
        result.recommendedActions.map((a) => a.code),
        containsAll(['DO_NOT_OPEN', 'DELETE_MESSAGE', 'IF_ALREADY_OPENED']),
      );
    });

    test('correspondance dans une liste périmée : SUSPICIOUS', () {
      expect(
        verdictOf(benign, [
          provider(ProviderStatus.match, age: const Duration(days: 30)),
        ]),
        UrlVerdict.suspicious,
      );
    });

    test('liste récente sans correspondance : NO_KNOWN_THREAT', () {
      final result = analyzer.analyzeWithReputation(benign, context, [
        provider(ProviderStatus.noMatch),
      ]);
      expect(result.verdict, UrlVerdict.noKnownThreat);
      expect(result.confidence, Confidence.medium);
      expect(
        result.recommendedActions.map((a) => a.code),
        contains('OPEN_ONLY_IF_EXPECTED'),
      );
    });

    test('les indices locaux priment sur l’absence de correspondance', () {
      expect(
        verdictOf(suspicious, [provider(ProviderStatus.noMatch)]),
        UrlVerdict.suspicious,
      );
    });

    test('liste périmée, source en erreur ou indisponible : INCONCLUSIVE', () {
      for (final result in [
        provider(ProviderStatus.noMatch, age: const Duration(days: 8)),
        provider(ProviderStatus.error),
        provider(ProviderStatus.unavailable),
        provider(ProviderStatus.stale, age: const Duration(days: 40)),
      ]) {
        expect(verdictOf(benign, [result]), UrlVerdict.inconclusive);
      }
    });

    test('âge maximal réglable', () {
      final strict = UrlAnalyzer(
        policy: const UrlVerdictPolicy(maxFeedAge: Duration(hours: 1)),
      );
      expect(strict.policy.maxFeedAge, const Duration(hours: 1));
      expect(
        strict.analyzeWithReputation(benign, context, [
          provider(ProviderStatus.match),
        ]).verdict,
        UrlVerdict.suspicious,
      );
    });

    test('confiance moyenne si les indices forts sont incertains', () {
      final (verdict, confidence) = const UrlVerdictPolicy().decide([
        RiskSignal(
          code: 'TEST_HIGH',
          severity: Severity.high,
          confidence: Confidence.medium,
          reason: 'test',
          source: SignalSource.urlHeuristic,
          detectedAt: now,
        ),
      ], const []);
      expect(verdict, UrlVerdict.suspicious);
      expect(confidence, Confidence.medium);
    });
  });

  group('masquage', () {
    test('noms et valeurs sensibles', () {
      expect(UrlMasking.isSensitiveName('access_token'), isTrue);
      expect(UrlMasking.isSensitiveName('X-Auth-Key'), isTrue);
      expect(UrlMasking.isSensitiveName('Code'), isTrue);
      expect(UrlMasking.isSensitiveName('page'), isFalse);
      expect(UrlMasking.isSensitiveValue('jean.dupont@example.com'), isTrue);
      expect(UrlMasking.isSensitiveValue('%2B226%2070%2000%2000%2000'), isTrue);
      expect(UrlMasking.isSensitiveValue('a1b2c3d4e5f6g7h8i9j0'), isTrue);
      expect(
        UrlMasking.isSensitiveValue('abcdefghijklmnopqrstuvwxyz'),
        isFalse,
      );
      expect(UrlMasking.isSensitiveValue('2026'), isFalse);
    });

    test('lien affiché', () {
      ParsedUrl url(String text) => UrlParser().parse(text) as ParsedUrl;
      expect(
        UrlMasking.maskedHref(url('https://u:secret@e.com/a?x=1&pin=1234&q')),
        'https://u:•••@e.com/a?x=1&pin=•••&q',
      );
      expect(
        UrlMasking.maskedHref(
          url('https://e.com/reset/a1b2c3d4e5f6g7h8i9j0k1l2#access_token=xyz'),
        ),
        'https://e.com/reset/•••#access_token=•••',
      );
      expect(
        UrlMasking.maskedHref(url('https://e.com/?a1b2c3d4e5f6g7h8i9j0&n=')),
        'https://e.com/?•••&n=',
      );
      expect(
        UrlMasking.maskedHref(url('https://e.com/#a1b2c3d4e5f6g7h8i9j0')),
        'https://e.com/#•••',
      );
      expect(
        UrlMasking.maskedHref(url('https://e.com:8080/#section')),
        'https://e.com:8080/#section',
      );
      expect(
        UrlMasking.maskedHref(url('https://jean@example.org@e.com/')),
        'https://•••@e.com/',
      );
    });

    test('troncature', () {
      expect(UrlMasking.truncate('abcdef', 10), 'abcdef');
      expect(UrlMasking.truncate('abcdef', 4), 'abc…');
      expect(UrlMasking.truncate('😀😀😀', 2), '😀…');
    });
  });
}
