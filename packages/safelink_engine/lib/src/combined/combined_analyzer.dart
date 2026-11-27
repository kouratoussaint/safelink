import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/analysis.dart';
import 'package:safelink_engine/src/common/notes.dart';
import 'package:safelink_engine/src/common/provider_result.dart';
import 'package:safelink_engine/src/common/verdicts.dart';
import 'package:safelink_engine/src/message/message_analyzer.dart';
import 'package:safelink_engine/src/message/message_extraction.dart';
import 'package:safelink_engine/src/url/url_analyzer.dart';

/// Lien d'un message et son analyse.
@immutable
final class LinkAssessment {
  /// Crée une analyse de lien.
  const new(this.link, this.result);

  /// Lien tel qu'il apparaît dans le message.
  final ExtractedLink link;

  /// Résultat de l'analyse du lien.
  final UrlAnalysisResult result;
}

/// Résultat combiné d'un message : l'analyse du texte et celle de chaque
/// lien restent séparées ; le niveau de synthèse est le plus sévère des
/// deux, pour qu'un texte rassurant ne masque jamais un lien dangereux.
final class CombinedResult {
  /// Crée un résultat combiné ; utilisé par [CombinedAnalyzer].
  new({
    required this.message,
    required List<LinkAssessment> links,
    required List<Limitation> limitations,
    required List<RecommendedAction> recommendedActions,
    required this.analyzedAt,
    required this.unanalyzedLinkCount,
  }) : links = List.unmodifiable(links),
       limitations = List.unmodifiable(limitations),
       recommendedActions = List.unmodifiable(recommendedActions);

  /// Analyse du texte.
  final MessageAnalysisResult message;

  /// Analyse de chaque lien, dans l'ordre du message.
  final List<LinkAssessment> links;

  /// Limites des deux analyses, sans doublon.
  final List<Limitation> limitations;

  /// Gestes recommandés, du plus important au plus général, sans doublon.
  final List<RecommendedAction> recommendedActions;

  /// Moment de l'analyse, en UTC.
  final DateTime analyzedAt;

  /// Liens repérés mais non analysés, au-delà du plafond.
  final int unanalyzedLinkCount;

  /// Niveau de synthèse : le plus sévère du texte et des liens.
  RiskLevel get level => RiskLevel.mostSevere([
    message.level,
    for (final link in links) link.result.level,
  ]);

  /// Lien dont le niveau est le plus sévère, s'il y en a.
  LinkAssessment? get mostSevereLink {
    if (links.isEmpty) return null;
    return links.reduce(
      (a, b) => b.result.level.rank > a.result.level.rank ? b : a,
    );
  }
}

/// Analyse combinée d'un message et de ses liens, entièrement sur
/// l'appareil.
final class CombinedAnalyzer {
  /// Crée un analyseur combiné.
  new({
    MessageAnalyzer? messageAnalyzer,
    UrlAnalyzer? urlAnalyzer,
    this.maxLinks = defaultMaxLinks,
  }) : messageAnalyzer = messageAnalyzer ?? MessageAnalyzer(),
       urlAnalyzer = urlAnalyzer ?? UrlAnalyzer() {
    if (maxLinks < 1) {
      throw ArgumentError.value(maxLinks, 'maxLinks', 'doit être positif');
    }
  }

  /// Nombre maximal de liens analysés par message.
  static const defaultMaxLinks = 10;

  /// Analyseur du texte.
  final MessageAnalyzer messageAnalyzer;

  /// Analyseur des liens.
  final UrlAnalyzer urlAnalyzer;

  /// Nombre maximal de liens analysés.
  final int maxLinks;

  /// Analyse [input] ; [reputation] fournit, pour un lien, les résultats de
  /// sources de réputation déjà obtenus (aucun au MVP).
  CombinedResult analyze(
    String input,
    AnalysisContext context, {
    List<ProviderResult> Function(ExtractedLink link)? reputation,
  }) {
    final message = messageAnalyzer.analyze(input, context);
    final extracted = message.extraction?.links ?? const <ExtractedLink>[];
    final analyzed = extracted.take(maxLinks).toList();
    final links = [
      for (final link in analyzed)
        LinkAssessment(
          link,
          urlAnalyzer.analyzeWithReputation(
            link.url,
            context,
            reputation?.call(link) ?? const [],
          ),
        ),
    ];
    final skipped = extracted.length - analyzed.length;

    final limitations = <Limitation>[];
    void addLimitation(Limitation limitation) {
      if (!limitations.any((l) => l.code == limitation.code)) {
        limitations.add(limitation);
      }
    }

    message.limitations.forEach(addLimitation);
    for (final link in links) {
      link.result.limitations.forEach(addLimitation);
    }
    if (skipped > 0) {
      addLimitation(
        Limitation(
          code: 'LINKS_NOT_ALL_ANALYZED',
          description:
              'Le message contient ${extracted.length} liens : seuls les '
              '$maxLinks premiers ont été analysés.',
        ),
      );
    }

    // Gestes : ceux du lien le plus risqué d'abord s'il dépasse le texte.
    final linkFirst =
        links.isNotEmpty &&
        links.any((l) => l.result.level.rank > message.level.rank);
    final sources = [
      if (linkFirst)
        ...(links.toList()..sort(
              (a, b) => b.result.level.rank.compareTo(a.result.level.rank),
            ))
            .map((l) => l.result.recommendedActions),
      message.recommendedActions,
      if (!linkFirst) ...links.map((l) => l.result.recommendedActions),
    ];
    final actions = <RecommendedAction>[];
    for (final list in sources) {
      for (final action in list) {
        if (!actions.any((a) => a.code == action.code)) actions.add(action);
      }
    }

    return CombinedResult(
      message: message,
      links: links,
      limitations: limitations,
      recommendedActions: actions,
      analyzedAt: context.now(),
      unanalyzedLinkCount: skipped,
    );
  }
}
