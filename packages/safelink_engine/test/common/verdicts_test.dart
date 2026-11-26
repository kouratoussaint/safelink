import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UrlVerdict', () {
    test('expose les codes normatifs du cahier des charges', () {
      expect(UrlVerdict.values.map((v) => v.code), [
        'KNOWN_THREAT',
        'SUSPICIOUS',
        'NO_KNOWN_THREAT',
        'INCONCLUSIVE',
        'INVALID',
      ]);
    });

    test('associe chaque verdict au niveau de synthèse prévu', () {
      expect(UrlVerdict.knownThreat.level, RiskLevel.danger);
      expect(UrlVerdict.suspicious.level, RiskLevel.attention);
      expect(UrlVerdict.inconclusive.level, RiskLevel.uncertain);
      expect(UrlVerdict.noKnownThreat.level, RiskLevel.nothingObvious);
      expect(UrlVerdict.invalid.level, RiskLevel.notAnalyzable);
    });
  });

  group('MessageVerdict', () {
    test('expose les codes normatifs du cahier des charges', () {
      expect(MessageVerdict.values.map((v) => v.code), [
        'HIGH_RISK_MESSAGE',
        'SUSPICIOUS_MESSAGE',
        'NO_OBVIOUS_SIGNALS',
        'INCONCLUSIVE_MESSAGE',
        'INVALID_MESSAGE',
      ]);
    });

    test('associe chaque verdict au niveau de synthèse prévu', () {
      expect(MessageVerdict.highRiskMessage.level, RiskLevel.danger);
      expect(MessageVerdict.suspiciousMessage.level, RiskLevel.attention);
      expect(MessageVerdict.inconclusiveMessage.level, RiskLevel.uncertain);
      expect(MessageVerdict.noObviousSignals.level, RiskLevel.nothingObvious);
      expect(MessageVerdict.invalidMessage.level, RiskLevel.notAnalyzable);
    });

    test("aucun code n'affirme l'authenticité ou la véracité", () {
      for (final verdict in MessageVerdict.values) {
        expect(verdict.code, isNot(contains('AUTHENTIC')));
        expect(verdict.code, isNot(contains('TRUE')));
        expect(verdict.code, isNot(contains('SAFE')));
      }
    });
  });

  group('RiskLevel.mostSevere', () {
    test('le niveau le plus sévère l’emporte toujours', () {
      expect(
        RiskLevel.mostSevere([
          MessageVerdict.noObviousSignals.level,
          UrlVerdict.knownThreat.level,
        ]),
        RiskLevel.danger,
      );
      expect(
        RiskLevel.mostSevere([
          MessageVerdict.suspiciousMessage.level,
          UrlVerdict.inconclusive.level,
          UrlVerdict.noKnownThreat.level,
        ]),
        RiskLevel.attention,
      );
    });

    test('un message rassurant ne masque jamais un lien dangereux', () {
      for (final message in MessageVerdict.values) {
        expect(
          RiskLevel.mostSevere([message.level, UrlVerdict.knownThreat.level]),
          RiskLevel.danger,
        );
      }
    });

    test('est indépendant de l’ordre', () {
      final levels = [
        RiskLevel.uncertain,
        RiskLevel.notAnalyzable,
        RiskLevel.attention,
        RiskLevel.nothingObvious,
      ];
      expect(RiskLevel.mostSevere(levels), RiskLevel.attention);
      expect(RiskLevel.mostSevere(levels.reversed), RiskLevel.attention);
    });

    test('refuse une liste vide plutôt que de rassurer', () {
      expect(() => RiskLevel.mostSevere(const []), throwsArgumentError);
    });

    test('les rangs sont strictement croissants', () {
      final ranks = RiskLevel.values.map((l) => l.rank).toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThan(ranks[i - 1]));
      }
    });
  });

  test('ContentType limite le MVP aux liens et messages', () {
    expect(ContentType.values.map((c) => c.code), ['url', 'message']);
  });
}
