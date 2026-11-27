import 'package:intl/intl.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Présentation du verdict d'une vérification enregistrée.
VerdictPresentation historyVerdict(HistoryEntry entry, AppLocalizations l10n) {
  final quiet =
      entry.details?.signals.every((s) => s.severity.rank < 2) ?? true;
  return switch (entry.kind) {
    AnalysisKind.link => VerdictPresentation.forUrlVerdict(
      urlVerdictOf(entry.verdictCode),
      l10n,
      quiet: quiet,
    ),
    AnalysisKind.message => VerdictPresentation.forMessageVerdict(
      messageVerdictOf(entry.verdictCode),
      l10n,
    ),
  };
}

/// Titre d'une vérification dans la liste.
String historyTitle(HistoryEntry entry, AppLocalizations l10n) {
  final details = entry.details;
  if (details == null) return l10n.historyUnreadable;
  return switch (entry.kind) {
    AnalysisKind.link => details.domain ?? l10n.historyInvalidLink,
    AnalysisKind.message => l10n.historyMessageLinks(details.links.length),
  };
}

/// Heure d'une vérification, à l'heure du téléphone.
String historyTime(DateTime utc) => DateFormat.Hm('fr').format(utc.toLocal());

/// Jour d'une vérification : « Aujourd'hui », « Hier » ou la date.
String historyDay(DateTime utc, DateTime now, AppLocalizations l10n) {
  final local = utc.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return l10n.historyToday;
  if (difference == 1) return l10n.historyYesterday;
  final format = local.year == now.year
      ? DateFormat('EEEE d MMMM', 'fr')
      : DateFormat('EEEE d MMMM y', 'fr');
  final text = format.format(local);
  return text[0].toUpperCase() + text.substring(1);
}

/// Période de filtrage de l'historique.
enum HistoryPeriod {
  /// Toutes les dates.
  all,

  /// Aujourd'hui.
  today,

  /// Les 7 derniers jours.
  week,

  /// Les 30 derniers jours.
  month;

  /// Vrai si [utc] tombe dans la période, par rapport à [now] (local).
  bool contains(DateTime utc, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (this) {
      HistoryPeriod.all => null,
      HistoryPeriod.today => today,
      HistoryPeriod.week => today.subtract(const Duration(days: 6)),
      HistoryPeriod.month => today.subtract(const Duration(days: 29)),
    };
    return start == null || !utc.toLocal().isBefore(start);
  }

  /// Libellé de la période.
  String label(AppLocalizations l10n) => switch (this) {
    HistoryPeriod.all => l10n.historyPeriodAll,
    HistoryPeriod.today => l10n.historyPeriodToday,
    HistoryPeriod.week => l10n.historyPeriodWeek,
    HistoryPeriod.month => l10n.historyPeriodMonth,
  };
}

/// Filtres de l'historique : nature, niveaux, période et domaine cherché.
final class HistoryFilter {
  /// Crée un filtre.
  const new({
    this.kind,
    this.levels = const {},
    this.period = HistoryPeriod.all,
    this.query = '',
  });

  /// Nature retenue, ou toutes si `null`.
  final AnalysisKind? kind;

  /// Niveaux retenus, ou tous si vide.
  final Set<RiskLevel> levels;

  /// Période retenue.
  final HistoryPeriod period;

  /// Texte cherché dans les domaines.
  final String query;

  /// Vrai si aucun filtre n'est actif.
  bool get isEmpty =>
      kind == null &&
      levels.isEmpty &&
      period == HistoryPeriod.all &&
      query.trim().isEmpty;

  /// Copie modifiée.
  HistoryFilter copyWith({
    AnalysisKind? Function()? kind,
    Set<RiskLevel>? levels,
    HistoryPeriod? period,
    String? query,
  }) => HistoryFilter(
    kind: kind == null ? this.kind : kind(),
    levels: levels ?? this.levels,
    period: period ?? this.period,
    query: query ?? this.query,
  );

  /// Vérifications retenues parmi [entries].
  List<HistoryEntry> apply(List<HistoryEntry> entries, DateTime now) {
    final needle = query.trim().toLowerCase();
    return [
      for (final entry in entries)
        if ((kind == null || entry.kind == kind) &&
            (levels.isEmpty || levels.contains(entry.level)) &&
            period.contains(entry.analyzedAt, now) &&
            (needle.isEmpty ||
                (entry.details?.domains.any(
                      (domain) => domain.toLowerCase().contains(needle),
                    ) ??
                    false)))
          entry,
    ];
  }
}
