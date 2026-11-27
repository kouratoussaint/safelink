import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Date seule, à l'heure du téléphone : « 24 novembre 2026 ».
String formatDay(DateTime utc) =>
    DateFormat('d MMMM y', 'fr').format(utc.toLocal());

/// Date et heure d'analyse, à l'heure du téléphone.
String formatAnalysisDate(DateTime utc) =>
    DateFormat("d MMMM y 'à' HH:mm", 'fr').format(utc.toLocal());

/// En-tête d'un verdict : icône, libellé, précision et confiance.
class VerdictHeader extends StatelessWidget {
  const new({
    required this.presentation,
    this.confidence,
    this.compact = false,
    this.showConfidence = true,
    super.key,
  });

  final VerdictPresentation presentation;

  /// Confiance dans le verdict, affichée si connue.
  final Confidence? confidence;

  /// Variante plus discrète, pour un sous-résultat.
  final bool compact;

  /// Affiche la confiance à l'écran ; sinon, seul TalkBack la lit.
  final bool showConfidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = VerdictPresentation.colorOf(context, presentation.level);
    final title = compact
        ? theme.textTheme.titleMedium
        : theme.textTheme.headlineSmall;
    final confidenceText = confidence == null
        ? null
        : VerdictPresentation.confidenceLabel(l10n, confidence!);
    return Semantics(
      container: true,
      header: true,
      value: showConfidence ? null : confidenceText,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              presentation.icon,
              color: color,
              size: compact ? 28 : 40,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(presentation.label, style: title?.copyWith(color: color)),
                if (presentation.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    presentation.subtitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (showConfidence && confidenceText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    confidenceText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SafeLinkColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de section avec titre.
class ResultSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Indice : gravité (icône, couleur et texte), explication, extrait.
class SignalTile extends StatelessWidget {
  const new({required this.signal, super.key});

  final RiskSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final level = VerdictPresentation.levelOfSeverity(signal.severity);
    final color = VerdictPresentation.colorOf(context, level);
    final evidence = signal.evidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(VerdictPresentation.iconOf(level), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VerdictPresentation.severityLabel(l10n, signal.severity),
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(signal.reason, style: theme.textTheme.bodyMedium),
                if (evidence != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.signalExcerpt('«\u00a0$evidence\u00a0»'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SafeLinkColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste à puces simple.
class BulletList extends StatelessWidget {
  const new({required this.items, this.icon = Icons.circle, super.key});

  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: icon == Icons.circle ? 8 : 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ligne « libellé : valeur » des détails techniques.
class DetailRow extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: SafeLinkColors.of(context).textSecondary,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Section repliable « Détails techniques ».
class TechnicalDetailsSection extends StatelessWidget {
  const new({required this.rows, super.key});

  final List<DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(l10n.sectionTechnical),
        leading: const ExcludeSemantics(child: Icon(Icons.code)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Valeurs copiables par appui long, sans transformer chaque ligne
        // en champ de texte pour TalkBack.
        children: [
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lignes techniques communes à toute analyse de lien.
List<DetailRow> urlDetailRows(UrlAnalysisResult result, AppLocalizations l10n) {
  final details = result.technicalDetails;
  final rows = <DetailRow>[];
  if (details != null) {
    rows.addAll([
      DetailRow(label: l10n.techDisplayedUrl, value: details.displayUrl),
      DetailRow(label: l10n.techHost, value: details.host),
      if (details.hostUnicode != details.host)
        DetailRow(label: l10n.techHostUnicode, value: details.hostUnicode),
      if (details.registrableDomain != null)
        DetailRow(
          label: l10n.techRegistrable,
          value: details.registrableDomain!,
        ),
      if (details.publicSuffix != null)
        DetailRow(
          label: l10n.techSuffix,
          value: details.isPrivateSuffix
              ? '${details.publicSuffix} (${l10n.techSharedHosting})'
              : details.publicSuffix!,
        ),
      if (details.port != null)
        DetailRow(label: l10n.techPort, value: '${details.port}'),
      if (details.scripts.isNotEmpty)
        DetailRow(
          label: l10n.techScripts,
          value: (details.scripts.toList()..sort()).join(', '),
        ),
      DetailRow(
        label: l10n.techNormalizations,
        value: details.normalizations.isEmpty
            ? l10n.techNone
            : details.normalizations.map((n) => n.description).join('\n'),
      ),
      DetailRow(
        label: l10n.techBrands,
        value: details.brandMatches.isEmpty
            ? l10n.techNone
            : details.brandMatches
                  .map(
                    (m) =>
                        '${m.brand.name} : '
                        '${VerdictPresentation.brandKindLabel(l10n, m.kind)}',
                  )
                  .join('\n'),
      ),
      DetailRow(
        label: l10n.techMasked(details.maskedValues),
        value: details.maskedValues == 0 ? l10n.techNone : '•••',
      ),
    ]);
  }
  final failure = result.failure;
  if (failure != null) {
    rows.add(
      DetailRow(
        label: l10n.techFailure,
        value: '${failure.error.description} (${failure.error.code})',
      ),
    );
  }
  rows.addAll(
    commonDetailRows(
      signals: result.signals,
      rulesVersion: result.rulesVersion,
      analyzedAt: result.analyzedAt,
      l10n: l10n,
      online: result.processing == Processing.localAndNetwork,
    ),
  );
  return rows;
}

/// Lignes techniques communes : codes, version, date, source.
List<DetailRow> commonDetailRows({
  required List<RiskSignal> signals,
  required String rulesVersion,
  required DateTime analyzedAt,
  required AppLocalizations l10n,
  bool online = false,
}) => [
  DetailRow(
    label: l10n.techSignals,
    value: signals.isEmpty
        ? l10n.techNone
        : signals
              .map(
                (s) =>
                    '${s.code} · '
                    '${VerdictPresentation.severityLabel(l10n, s.severity)}',
              )
              .join('\n'),
  ),
  DetailRow(label: l10n.techRules, value: rulesVersion),
  DetailRow(label: l10n.techAnalyzedAt, value: formatAnalysisDate(analyzedAt)),
  DetailRow(
    label: l10n.techSource,
    value: online ? l10n.techSourceOnline : l10n.techSourceLocal,
  ),
];
