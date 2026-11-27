import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 11, 26, 12);
  final match = ThreatMatch(
    threatType: ThreatType.phishing,
    reportedAt: DateTime.utc(2026, 11, 20),
  );

  group('ProviderResult', () {
    test('calcule l’âge de la liste', () {
      final result = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.noMatch,
        checkedAt: checkedAt,
        feedUpdatedAt: checkedAt.subtract(const Duration(hours: 30)),
      );
      expect(result.feedAge, const Duration(hours: 30));
      expect(result.isFreshWithin(const Duration(days: 2)), isTrue);
      expect(result.isFreshWithin(const Duration(hours: 24)), isFalse);
      expect(result.isConclusive, isTrue);
    });

    test('une liste sans date n’est jamais considérée comme récente', () {
      final result = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.noMatch,
        checkedAt: checkedAt,
      );
      expect(result.feedAge, isNull);
      expect(result.isFreshWithin(const Duration(days: 365)), isFalse);
    });

    test('« match » exige une correspondance, les autres statuts aucune', () {
      expect(
        ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.match,
          checkedAt: checkedAt,
          matches: [match],
        ).matches,
        [match],
      );
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.match,
          checkedAt: checkedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.noMatch,
          checkedAt: checkedAt,
          matches: [match],
        ),
        throwsArgumentError,
      );
    });

    test('un code d’erreur est requis pour « error » et seulement là', () {
      final error = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.error,
        checkedAt: checkedAt,
        errorCode: 'QUOTA_EXCEEDED',
      );
      expect(error.isConclusive, isFalse);
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.error,
          checkedAt: checkedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.unavailable,
          checkedAt: checkedAt,
          errorCode: 'QUOTA_EXCEEDED',
        ),
        throwsArgumentError,
      );
    });

    test('indisponible, périmé et erreur ne permettent pas de conclure', () {
      for (final status in [ProviderStatus.unavailable, ProviderStatus.stale]) {
        expect(
          ProviderResult(
            providerId: 'TEST_SOURCE',
            status: status,
            checkedAt: checkedAt,
          ).isConclusive,
          isFalse,
          reason: status.name,
        );
      }
    });

    test('refuse une liste datée après la vérification', () {
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.noMatch,
          checkedAt: checkedAt,
          feedUpdatedAt: checkedAt.add(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('refuse les dates locales', () {
      expect(
        () => ProviderResult(
          providerId: 'TEST_SOURCE',
          status: ProviderStatus.noMatch,
          checkedAt: DateTime(2026, 11, 26),
        ),
        throwsArgumentError,
      );
      expect(
        () => ThreatMatch(
          threatType: ThreatType.malware,
          reportedAt: DateTime(2026, 11, 26),
        ),
        throwsArgumentError,
      );
    });

    test('les correspondances ne sont pas modifiables', () {
      final result = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.match,
        checkedAt: checkedAt,
        matches: [match],
      );
      expect(() => result.matches.add(match), throwsUnsupportedError);
    });

    test('compare par valeur', () {
      ProviderResult build() => ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.match,
        checkedAt: checkedAt,
        matches: [match],
        feedVersion: '2026-11-26',
      );
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build().toString(), 'ProviderResult(TEST_SOURCE, match)');
      final twoMatches = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.match,
        checkedAt: checkedAt,
        matches: [
          match,
          ThreatMatch(threatType: ThreatType.other),
        ],
        feedVersion: '2026-11-26',
      );
      expect(build(), isNot(twoMatches));
      final otherMatch = ProviderResult(
        providerId: 'TEST_SOURCE',
        status: ProviderStatus.match,
        checkedAt: checkedAt,
        matches: [ThreatMatch(threatType: ThreatType.malware)],
        feedVersion: '2026-11-26',
      );
      expect(build(), isNot(otherMatch));
      expect(match, isNot(ThreatMatch(threatType: ThreatType.phishing)));
      expect(match.hashCode, isA<int>());
    });
  });
}
