import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Résumé texte d'une analyse, pour « Copier le résumé ».
///
/// Il ne contient jamais le texte d'un message ni d'extrait : seulement les
/// verdicts, les explications, les limites, les gestes et les liens avec
/// leurs données sensibles masquées.
abstract final class ResultSummary {
  /// Résumé de [outcome] ; [formatDate] met en forme la date d'analyse.
  static String of(
    AnalysisOutcome outcome,
    AppLocalizations l10n,
    String Function(DateTime) formatDate,
  ) {
    final lines = <String>[
      l10n.summaryHeader,
      l10n.summaryAnalyzedAt(formatDate(outcome.analyzedAt)),
      '',
    ];
    switch (outcome) {
      case LinkOutcome(:final result):
        _url(lines, result, l10n);
        _list(
          lines,
          l10n.sectionWhatToDo,
          result.recommendedActions.map((a) => a.description),
        );
        _list(
          lines,
          l10n.sectionNotChecked,
          result.limitations.map((l) => l.description),
        );
      case MessageOutcome(:final result):
        final message = result.message;
        final presentation = VerdictPresentation.forMessage(message, l10n);
        lines
          ..add(
            l10n.combinedTitle(
              VerdictPresentation.levelLabel(l10n, result.level),
            ),
          )
          ..add(l10n.summaryMessage)
          ..add(l10n.summaryVerdict(presentation.label));
        _list(
          lines,
          l10n.sectionTextSignals,
          message.signals.map((s) => s.reason),
        );
        for (final link in result.links) {
          lines.add('');
          _url(lines, link.result, l10n);
        }
        _list(
          lines,
          l10n.sectionWhatToDo,
          result.recommendedActions.map((a) => a.description),
        );
        _list(
          lines,
          l10n.sectionNotChecked,
          result.limitations.map((l) => l.description),
        );
    }
    lines
      ..add('')
      ..add(
        outcome.online == OnlineStatus.done
            ? l10n.summaryOnlineDone
            : l10n.summaryOnlineNotDone,
      )
      ..add(l10n.summaryFooter);
    return lines.join('\n');
  }

  static void _url(
    List<String> lines,
    UrlAnalysisResult result,
    AppLocalizations l10n,
  ) {
    final shown = result.technicalDetails?.displayUrl;
    if (shown != null) lines.add(l10n.summaryLink(shown));
    lines.add(
      l10n.summaryVerdict(VerdictPresentation.forUrl(result, l10n).label),
    );
    _list(lines, l10n.sectionWhy, result.signals.map((s) => s.reason));
  }

  static void _list(List<String> lines, String title, Iterable<String> items) {
    if (items.isEmpty) return;
    lines
      ..add('')
      ..add('$title :');
    for (final item in items) {
      lines.add('- $item');
    }
  }
}
