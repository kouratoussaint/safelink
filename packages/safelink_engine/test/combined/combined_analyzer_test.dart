import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 9);
  final context = AnalysisContext(clock: () => now);
  final analyzer = CombinedAnalyzer();

  ProviderResult match() => ProviderResult(
    providerId: 'TEST_PROVIDER',
    status: ProviderStatus.match,
    checkedAt: now,
    feedUpdatedAt: now.subtract(const Duration(hours: 1)),
    matches: [ThreatMatch(threatType: ThreatType.phishing)],
  );

  test('lien dangereux dans un message apparemment neutre', () {
    final result = analyzer.analyze(
      'Bonjour, voici les photos de la fête : https://photos-fete.example/a',
      context,
      reputation: (_) => [match()],
    );
    expect(result.message.verdict, MessageVerdict.noObviousSignals);
    expect(result.links.single.result.verdict, UrlVerdict.knownThreat);
    expect(result.level, RiskLevel.danger);
    expect(result.mostSevereLink, result.links.single);
    expect(
      result.recommendedActions.first.code,
      'DO_NOT_OPEN',
      reason: 'les gestes du lien le plus risqué passent en premier',
    );
  });

  test('message suspect avec un lien sans menace connue', () {
    final result = analyzer.analyze(
      'Envoyez-moi le code reçu par SMS. Infos : https://www.orange.bf',
      context,
    );
    expect(result.message.verdict, MessageVerdict.highRiskMessage);
    expect(result.links.single.result.verdict, UrlVerdict.inconclusive);
    expect(result.level, RiskLevel.danger);
    expect(result.recommendedActions.first.code, 'NEVER_SHARE_CODES');
  });

  test('un message rassurant n’abaisse jamais un lien suspect', () {
    final result = analyzer.analyze(
      'Tout va bien, rien à craindre : https://paypa1.com/login',
      context,
    );
    expect(result.message.level.rank, lessThan(RiskLevel.attention.rank));
    expect(result.links.single.result.verdict, UrlVerdict.suspicious);
    expect(result.level, RiskLevel.attention);
  });

  test('analyse hors ligne : limites des deux analyses, sans doublon', () {
    final result = analyzer.analyze(
      'Voir https://example.com et https://example.org',
      context,
    );
    final codes = result.limitations.map((l) => l.code).toList();
    expect(codes.toSet(), hasLength(codes.length));
    expect(
      codes,
      containsAll(['SENDER_NOT_VERIFIED', 'REPUTATION_UNAVAILABLE']),
    );
    final actions = result.recommendedActions.map((a) => a.code).toList();
    expect(actions.toSet(), hasLength(actions.length));
    expect(result.analyzedAt, now);
  });

  test('message sans lien', () {
    final result = analyzer.analyze('Bonjour, à demain au bureau.', context);
    expect(result.links, isEmpty);
    expect(result.mostSevereLink, isNull);
    expect(result.level, RiskLevel.nothingObvious);
    expect(result.unanalyzedLinkCount, 0);
  });

  test('message non analysable', () {
    final result = analyzer.analyze('', context);
    expect(result.links, isEmpty);
    expect(result.level, RiskLevel.notAnalyzable);
  });

  test('plafond du nombre de liens', () {
    final small = CombinedAnalyzer(maxLinks: 2);
    expect(small.maxLinks, 2);
    final result = small.analyze(
      'a https://a.example.com b https://b.example.com c https://c.example.com',
      context,
    );
    expect(result.links, hasLength(2));
    expect(result.unanalyzedLinkCount, 1);
    expect(
      result.limitations.map((l) => l.code),
      contains('LINKS_NOT_ALL_ANALYZED'),
    );
    expect(() => CombinedAnalyzer(maxLinks: 0), throwsArgumentError);
    expect(small.messageAnalyzer, isA<MessageAnalyzer>());
    expect(small.urlAnalyzer, isA<UrlAnalyzer>());
  });

  test('lien déguisé analysé sous sa forme réelle', () {
    final result = analyzer.analyze(
      'Attention à hxxps://paypa1[.]com/login',
      context,
    );
    final link = result.links.single;
    expect(link.link.isDefanged, isTrue);
    expect(link.result.url?.host, 'paypa1.com');
    expect(link.result.verdict, UrlVerdict.suspicious);
  });
}
