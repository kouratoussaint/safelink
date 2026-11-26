import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

/// Résultat minimal pour tester la classe de base.
final class _FakeResult extends AnalysisResult {
  new({
    required super.signals,
    required super.limitations,
    DateTime? analyzedAt,
  }) : super(
         analyzedAt: analyzedAt ?? DateTime.utc(2026, 11, 26),
         contentType: ContentType.message,
         recommendedActions: const [],
         rulesVersion: 'test-1',
         processing: Processing.localOnly,
         privacyImpact: PrivacyImpact.stayedOnDevice,
       );

  @override
  RiskLevel get level => RiskLevel.uncertain;
}

/// Analyseur minimal prouvant que le contrat est implémentable.
final class _EchoAnalyzer implements ContentAnalyzer<String, _FakeResult> {
  @override
  ContentType get contentType => ContentType.message;

  @override
  _FakeResult analyze(String input, AnalysisContext context) => _FakeResult(
    signals: const [],
    limitations: [_limitation],
    analyzedAt: context.now(),
  );
}

final _limitation = Limitation(
  code: 'TEST_LIMITATION',
  description: 'Limite de test.',
);

void main() {
  group('AnalysisContext', () {
    test('renvoie toujours une heure UTC', () {
      final context = AnalysisContext(
        clock: () => DateTime(2026, 11, 26, 21, 30),
      );
      expect(context.now().isUtc, isTrue);
    });

    test('utilise le français par défaut', () {
      expect(const AnalysisContext().languageCode, 'fr');
    });
  });

  group('AnalysisResult', () {
    test('exige au moins une limite', () {
      expect(
        () => _FakeResult(signals: const [], limitations: const []),
        throwsArgumentError,
      );
    });

    test('expose des listes non modifiables', () {
      final result = _FakeResult(signals: const [], limitations: [_limitation]);
      expect(result.limitations.clear, throwsUnsupportedError);
      expect(result.signals.clear, throwsUnsupportedError);
      expect(result.recommendedActions.clear, throwsUnsupportedError);
    });

    test('refuse une date locale', () {
      expect(
        () => _FakeResult(
          signals: const [],
          limitations: [_limitation],
          analyzedAt: DateTime(2026, 11, 26),
        ),
        throwsArgumentError,
      );
    });
  });

  test('un analyseur est déterministe pour une heure donnée', () {
    final analyzer = _EchoAnalyzer();
    final context = AnalysisContext(clock: () => DateTime.utc(2026, 11, 26));
    final first = analyzer.analyze('bonjour', context);
    final second = analyzer.analyze('bonjour', context);
    expect(first.analyzedAt, second.analyzedAt);
    expect(analyzer.contentType, ContentType.message);
  });
}
