import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 11, 26, 12);

  RiskSignal signal({
    String code = 'USERINFO_PRESENT',
    String reason = 'Le lien contient un faux nom de site avant « @ ».',
    DateTime? detectedAt,
    String? evidence,
  }) => RiskSignal(
    code: code,
    severity: Severity.high,
    confidence: Confidence.high,
    reason: reason,
    source: SignalSource.urlHeuristic,
    detectedAt: detectedAt ?? at,
    evidence: evidence,
  );

  group('RiskSignal', () {
    test('accepte un indice valide', () {
      final s = signal(evidence: 'banque.example@autre-site.test');
      expect(s.code, 'USERINFO_PRESENT');
      expect(s.evidence, 'banque.example@autre-site.test');
    });

    test('refuse un code mal formé', () {
      for (final code in ['', 'ab', 'lowercase_code', '1ABC', 'AVEC-TIRET']) {
        expect(() => signal(code: code), throwsArgumentError, reason: code);
      }
    });

    test('refuse une raison vide', () {
      expect(() => signal(reason: '   '), throwsArgumentError);
    });

    test('refuse une date qui n’est pas en UTC', () {
      expect(
        () => signal(detectedAt: DateTime(2026, 11, 26, 12)),
        throwsArgumentError,
      );
    });

    test('limite la longueur des extraits', () {
      const limit = RiskSignal.maxEvidenceLength;
      expect(signal(evidence: 'a' * limit).evidence, hasLength(limit));
      expect(() => signal(evidence: 'a' * (limit + 1)), throwsArgumentError);
      expect(() => signal(evidence: '  '), throwsArgumentError);
    });

    test('compare par valeur', () {
      expect(signal(), signal());
      expect(signal().hashCode, signal().hashCode);
      expect(signal(), isNot(signal(evidence: 'x')));
    });
  });

  group('Severity', () {
    test('les rangs sont strictement croissants', () {
      final ranks = Severity.values.map((s) => s.rank).toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThan(ranks[i - 1]));
      }
    });
  });

  group('Limitation et RecommendedAction', () {
    test('valident code et texte', () {
      expect(
        Limitation(
          code: 'REPUTATION_NOT_CHECKED',
          description: 'La réputation du lien n’a pas été vérifiée.',
        ).code,
        'REPUTATION_NOT_CHECKED',
      );
      expect(
        () => Limitation(code: 'bad', description: 'x'),
        throwsArgumentError,
      );
      expect(
        () => RecommendedAction(code: 'NEVER_SHARE_CODES', description: ''),
        throwsArgumentError,
      );
    });

    test('comparent par valeur', () {
      RecommendedAction action() => RecommendedAction(
        code: 'NEVER_SHARE_CODES',
        description: 'Ne communiquez jamais un code reçu par SMS.',
      );
      Limitation limitation([String text = 'Non vérifié.']) =>
          Limitation(code: 'REPUTATION_NOT_CHECKED', description: text);
      expect(action(), action());
      expect(action().hashCode, action().hashCode);
      expect(limitation(), limitation());
      expect(limitation().hashCode, limitation().hashCode);
      expect(limitation(), isNot(limitation('Autre texte.')));
    });

    test("s'affichent par leur code, sans le texte", () {
      expect(
        Limitation(code: 'OFFLINE', description: 'Hors ligne.').toString(),
        'Limitation(OFFLINE)',
      );
      expect(
        RecommendedAction(
          code: 'CHECK_OFFICIAL_APP',
          description: 'Vérifiez dans l’application officielle.',
        ).toString(),
        'RecommendedAction(CHECK_OFFICIAL_APP)',
      );
    });
  });

  test("RiskSignal s'affiche sans raison ni extrait", () {
    final text = signal(evidence: 'secret').toString();
    expect(text, 'RiskSignal(USERINFO_PRESENT, high, urlHeuristic)');
    expect(text, isNot(contains('secret')));
  });
}
