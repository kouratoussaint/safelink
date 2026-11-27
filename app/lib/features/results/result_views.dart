import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/checklist.dart';
import 'package:safelink/features/results/online_section.dart';
import 'package:safelink/features/results/page_preview_card.dart';
import 'package:safelink/features/results/result_summary.dart';
import 'package:safelink/features/results/result_widgets.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Contenu du résultat d'un lien : verdict, pourquoi, ce qui n'a pas été
/// vérifié, que faire, détails techniques. Aucun bouton pour ouvrir le
/// lien : SafeLink ne l'ouvre jamais.
class LinkResultView extends StatelessWidget {
  const new({
    required this.result,
    this.online = OnlineStatus.notRequested,
    this.onRetry,
    this.footer = const [],
    super.key,
  });

  final UrlAnalysisResult result;

  /// État de la vérification en ligne de ce lien.
  final OnlineStatus online;

  /// Relance l'analyse si les services en ligne n'ont pas répondu.
  final VoidCallback? onRetry;

  /// Éléments ajoutés en bas (actions).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presentation = VerdictPresentation.forUrl(result, l10n);
    final displayed = result.technicalDetails?.displayUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VerdictHeader(
          presentation: presentation,
          confidence: result.verdict == UrlVerdict.invalid
              ? null
              : result.confidence,
        ),
        if (displayed != null) ...[
          const SizedBox(height: 12),
          HighlightedUrl(
            displayed: displayed,
            domain:
                result.technicalDetails!.registrableDomain ??
                result.technicalDetails!.host,
          ),
        ],
        PagePreviewCard(result: result),
        if (result.url != null) const OnlineOfferCard(),
        const SizedBox(height: 16),
        ResultSection(
          title: l10n.sectionWhy,
          children: result.signals.isEmpty
              ? [Text(l10n.sectionWhyEmpty)]
              : [for (final s in result.signals) SignalTile(signal: s)],
        ),
        const SizedBox(height: 12),
        ResultSection(
          title: l10n.sectionWhatToDo,
          children: [
            BulletList(
              icon: Icons.check_circle_outline,
              items: [for (final a in result.recommendedActions) a.description],
            ),
          ],
        ),
        if (result.url != null) ...[
          const SizedBox(height: 12),
          OnlineSection(result: result, status: online, onRetry: onRetry),
          const SizedBox(height: 12),
          ChecklistSection(items: urlChecklist(result, l10n)),
        ],
        const SizedBox(height: 12),
        ResultSection(
          title: l10n.sectionNotChecked,
          children: [
            BulletList(
              icon: Icons.info_outline,
              items: [for (final l in result.limitations) l.description],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TechnicalDetailsSection(rows: urlDetailRows(result, l10n)),
        ...footer,
      ],
    );
  }
}

/// Lien affiché avec son domaine enregistré mis en évidence.
class HighlightedUrl extends StatelessWidget {
  const new({required this.displayed, required this.domain, super.key});

  final String displayed;
  final String domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;
    final index = displayed.indexOf(domain);
    final spans = index < 0
        ? [TextSpan(text: displayed)]
        : [
            TextSpan(text: displayed.substring(0, index)),
            TextSpan(
              text: domain,
              style: base?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextSpan(text: displayed.substring(index + domain.length)),
          ];
    return Text.rich(
      TextSpan(
        style: base?.copyWith(color: SafeLinkColors.of(context).textSecondary),
        children: spans,
      ),
    );
  }
}

/// Contenu du résultat d'un message : synthèse, indices dans le texte,
/// liens repérés et leurs résultats, limites, gestes recommandés.
class MessageResultView extends StatelessWidget {
  const new({
    required this.result,
    required this.onOpenLink,
    this.online = OnlineStatus.notRequested,
    this.footer = const [],
    super.key,
  });

  final CombinedResult result;

  /// État de la vérification en ligne des liens du message.
  final OnlineStatus online;

  /// Ouvre le résultat détaillé d'un lien.
  final void Function(LinkAssessment link) onOpenLink;

  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final message = result.message;
    final levelColor = VerdictPresentation.colorOf(context, result.level);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: levelColor, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              container: true,
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      VerdictPresentation.iconOf(result.level),
                      color: levelColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.combinedTitle(
                            VerdictPresentation.levelLabel(l10n, result.level),
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: levelColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(l10n.combinedBody),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        VerdictHeader(
          presentation: VerdictPresentation.forMessage(message, l10n),
          confidence: message.verdict == MessageVerdict.invalidMessage
              ? null
              : message.confidence,
          compact: true,
        ),
        if (result.links.isNotEmpty) const OnlineOfferCard(),
        const SizedBox(height: 16),
        ResultSection(
          title: l10n.sectionTextSignals,
          children: message.signals.isEmpty
              ? [Text(l10n.sectionTextSignalsEmpty)]
              : [for (final s in message.signals) SignalTile(signal: s)],
        ),
        const SizedBox(height: 12),
        ResultSection(
          title: l10n.sectionLinks,
          children: [
            if (result.links.isEmpty) Text(l10n.sectionLinksEmpty),
            for (final link in result.links) _LinkTile(link, onOpenLink),
            if (result.unanalyzedLinkCount > 0)
              Text(l10n.linksNotAnalyzed(result.unanalyzedLinkCount)),
            if (result.links.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  switch (online) {
                    OnlineStatus.done => l10n.onlineMessageDone,
                    OnlineStatus.unreachable => l10n.onlineMessageUnreachable,
                    _ => l10n.onlineMessageDisabled,
                  },
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafeLinkColors.of(context).textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ResultSection(
          title: l10n.sectionWhatToDo,
          children: [
            BulletList(
              icon: Icons.check_circle_outline,
              items: [for (final a in result.recommendedActions) a.description],
            ),
          ],
        ),
        if (message.verdict != MessageVerdict.invalidMessage) ...[
          const SizedBox(height: 12),
          ChecklistSection(items: messageChecklist(message, l10n)),
        ],
        const SizedBox(height: 12),
        ResultSection(
          title: l10n.sectionNotChecked,
          children: [
            BulletList(
              icon: Icons.info_outline,
              items: [for (final l in result.limitations) l.description],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TechnicalDetailsSection(
          rows: commonDetailRows(
            signals: message.signals,
            rulesVersion: message.rulesVersion,
            analyzedAt: message.analyzedAt,
            l10n: l10n,
            online: online == OnlineStatus.done,
          ),
        ),
        ...footer,
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const new(this.link, this.onOpen);

  final LinkAssessment link;
  final void Function(LinkAssessment link) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presentation = VerdictPresentation.forUrl(link.result, l10n);
    final color = VerdictPresentation.colorOf(context, presentation.level);
    final shown =
        link.result.technicalDetails?.displayUrl ??
        UrlMasking.truncate(link.link.written, 80);
    return ListTile(
      key: ValueKey('link-${link.link.span.start}'),
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(child: Icon(presentation.icon, color: color)),
      title: Text(shown, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          presentation.label,
          if (link.link.isDefanged) l10n.linkDefanged,
        ].join(' · '),
        style: TextStyle(color: color),
      ),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: () => onOpen(link),
      minTileHeight: 56,
    );
  }
}

/// Actions en bas d'un résultat : copier le résumé expurgé, nouvelle
/// analyse.
class ResultActions extends StatelessWidget {
  const new({required this.outcome, super.key});

  final AnalysisOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.copySummary),
            onPressed: () async {
              final summary = ResultSummary.of(
                outcome,
                l10n,
                formatAnalysisDate,
              );
              await Clipboard.setData(ClipboardData(text: summary));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.summaryCopied)));
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            label: Text(l10n.newAnalysis),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}
