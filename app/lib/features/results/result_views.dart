import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/short_links.dart';
import 'package:safelink/features/results/checklist.dart';
import 'package:safelink/features/results/destination_card.dart';
import 'package:safelink/features/results/online_section.dart';
import 'package:safelink/features/results/page_preview_card.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/result_summary.dart';
import 'package:safelink/features/results/result_widgets.dart';
import 'package:safelink/features/results/verdict_hero.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Contenu du résultat d'un lien : verdict en grand, aperçu de la page,
/// raisons et gestes en pictogrammes ; explications et détails techniques
/// repliés hors du mode expert. Aucun bouton pour ouvrir le lien :
/// SafeLink ne l'ouvre jamais.
class LinkResultView extends ConsumerWidget {
  const new({
    required this.result,
    this.destination,
    this.online = OnlineStatus.notRequested,
    this.onRetry,
    this.footer = const [],
    super.key,
  });

  final UrlAnalysisResult result;

  /// Vraie destination analysée, si le lien est raccourci.
  final UrlAnalysisResult? destination;

  /// État de la vérification en ligne de ce lien.
  final OnlineStatus online;

  /// Relance l'analyse si les services en ligne n'ont pas répondu.
  final VoidCallback? onRetry;

  /// Éléments ajoutés en bas (actions).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expert = ref.watch(expertModeProvider);
    final destination = this.destination;
    final presentation = VerdictPresentation.forLinkWithDestination(
      result,
      destination,
      l10n,
    );
    final details = result.technicalDetails;
    final url = result.url;
    final shortened = url != null && ShortLinkResolver.isShortener(url);
    final looked =
        online == OnlineStatus.done || online == OnlineStatus.unreachable;
    // Raisons et gestes du lien et, s'il est raccourci, de sa destination.
    final signals = {
      for (final s in [...result.signals, ...?destination?.signals])
        '${s.code}|${s.evidence}': s,
    }.values.toList();
    // Gestes : ceux de la destination quand elle est plus grave (« Ouvrez
    // seulement si vous l'attendiez » n'a plus de sens face à un danger).
    final actions =
        destination != null && destination.level.rank > result.level.rank
        ? destination.recommendedActions
        : result.recommendedActions;
    final explanations = [
      if (result.url != null) ...[
        OnlineSection(result: result, status: online, onRetry: onRetry),
        ChecklistSection(items: urlChecklist(result, l10n)),
      ],
      ResultSection(
        title: l10n.sectionNotChecked,
        children: [
          BulletList(
            icon: Icons.info_outline,
            items: [for (final l in result.limitations) l.description],
          ),
        ],
      ),
    ];
    final children = <Widget>[
      VerdictHero(
        presentation: presentation,
        expert: expert,
        confidence: result.verdict == UrlVerdict.invalid
            ? null
            : result.confidence,
        speech: verdictSpeech(
          l10n,
          presentation,
          signals: signals,
          actions: actions,
        ),
      ),
      if (online == OnlineStatus.unreachable) OfflineBanner(onRetry: onRetry),
      if (details != null)
        AddressBar(
          displayed: details.displayUrl,
          domain: details.registrableDomain ?? details.host,
          color: VerdictPresentation.colorOf(
            context,
            VerdictPresentation.forUrl(result, l10n).level,
          ),
        ),
      if (shortened && (destination != null || looked))
        DestinationCard(destination: destination),
      if (PagePreviewCard.applies(result, ref, target: destination?.url))
        PagePreviewCard(
          result: result,
          target: destination?.url,
          level: presentation.level,
          showRedirect: destination == null,
        ),
      ResultSection(
        title: l10n.sectionWhy,
        children: [
          ReasonList(
            signals: signals,
            expert: expert,
            emptyText: l10n.sectionWhyEmpty,
          ),
        ],
      ),
      ResultSection(
        title: l10n.sectionWhatToDo,
        children: [ActionGrid(actions: actions, expert: expert)],
      ),
      if (expert) ...[
        ...explanations,
        TechnicalDetailsSection(rows: urlDetailRows(result, l10n)),
      ] else
        MoreSection(children: explanations),
      ...footer,
    ];
    return ResultList(children: children);
  }
}

/// Liste d'un résultat : les blocs apparaissent l'un après l'autre.
class ResultList extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      for (final (i, child) in children.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: Appear(index: i, child: child),
        ),
    ],
  );
}

/// Adresse du lien, comme dans la barre d'un navigateur, avec le vrai nom
/// du site en gras.
class AddressBar extends StatelessWidget {
  const new({
    required this.displayed,
    required this.domain,
    required this.color,
    super.key,
  });

  final String displayed;
  final String domain;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.link_rounded, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: HighlightedUrl(displayed: displayed, domain: domain),
          ),
        ],
      ),
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

/// Contenu du résultat d'un message : synthèse en grand, indices du texte
/// et liens en pictogrammes, aperçu du premier lien, gestes ; limites et
/// détails repliés hors du mode expert.
class MessageResultView extends ConsumerWidget {
  const new({
    required this.result,
    required this.onOpenLink,
    this.destinations = const {},
    this.online = OnlineStatus.notRequested,
    this.onRetry,
    this.footer = const [],
    super.key,
  });

  /// Relance l'analyse si les services en ligne n'ont pas répondu.
  final VoidCallback? onRetry;

  final CombinedResult result;

  /// Vraie destination analysée des liens raccourcis, par adresse du lien.
  final Map<String, UrlAnalysisResult> destinations;

  /// État de la vérification en ligne des liens du message.
  final OnlineStatus online;

  /// Ouvre le résultat détaillé d'un lien.
  final void Function(LinkAssessment link) onOpenLink;

  final List<Widget> footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expert = ref.watch(expertModeProvider);
    final message = result.message;
    final presentation = VerdictPresentation.forCombined(
      RiskLevel.mostSevere([
        result.level,
        for (final d in destinations.values) d.level,
      ]),
      l10n,
    );
    final firstLink = result.links.firstOrNull;
    final explanations = [
      if (message.verdict != MessageVerdict.invalidMessage)
        ChecklistSection(items: messageChecklist(message, l10n)),
      ResultSection(
        title: l10n.sectionNotChecked,
        children: [
          BulletList(
            icon: Icons.info_outline,
            items: [for (final l in result.limitations) l.description],
          ),
        ],
      ),
    ];
    final children = <Widget>[
      VerdictHero(
        presentation: presentation,
        expert: expert,
        speech: verdictSpeech(
          l10n,
          presentation,
          signals: [
            ...message.signals,
            for (final link in result.links) ...link.result.signals,
            for (final d in destinations.values) ...d.signals,
          ],
          actions: result.recommendedActions,
        ),
      ),
      if (online == OnlineStatus.unreachable) OfflineBanner(onRetry: onRetry),
      ResultSection(
        title: l10n.sectionTextSignals,
        children: [
          VerdictHeader(
            presentation: VerdictPresentation.forMessage(message, l10n),
            confidence: message.verdict == MessageVerdict.invalidMessage
                ? null
                : message.confidence,
            compact: true,
            showConfidence: expert,
          ),
          const SizedBox(height: 12),
          ReasonList(
            signals: message.signals,
            expert: expert,
            emptyText: l10n.sectionTextSignalsEmpty,
          ),
        ],
      ),
      ResultSection(
        title: l10n.sectionLinks,
        children: [
          if (result.links.isEmpty) Text(l10n.sectionLinksEmpty),
          for (final link in result.links)
            _LinkTile(
              link,
              onOpenLink,
              destination: destinations[link.result.url?.href],
            ),
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
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: SafeLinkColors.of(context).textSecondary),
              ),
            ),
        ],
      ),
      if (firstLink != null &&
          PagePreviewCard.applies(
            firstLink.result,
            ref,
            target: destinations[firstLink.result.url?.href]?.url,
          ))
        PagePreviewCard(
          result: firstLink.result,
          target: destinations[firstLink.result.url?.href]?.url,
          level: VerdictPresentation.forLinkWithDestination(
            firstLink.result,
            destinations[firstLink.result.url?.href],
            l10n,
          ).level,
        ),
      ResultSection(
        title: l10n.sectionWhatToDo,
        children: [
          ActionGrid(actions: result.recommendedActions, expert: expert),
        ],
      ),
      if (expert) ...[
        ...explanations,
        TechnicalDetailsSection(
          rows: commonDetailRows(
            signals: message.signals,
            rulesVersion: message.rulesVersion,
            analyzedAt: message.analyzedAt,
            l10n: l10n,
            online: online == OnlineStatus.done,
          ),
        ),
      ] else
        MoreSection(children: explanations),
      ...footer,
    ];
    return ResultList(children: children);
  }
}

class _LinkTile extends StatelessWidget {
  const new(this.link, this.onOpen, {this.destination});

  final LinkAssessment link;
  final void Function(LinkAssessment link) onOpen;

  /// Vraie destination, si le lien est raccourci.
  final UrlAnalysisResult? destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presentation = VerdictPresentation.forLinkWithDestination(
      link.result,
      destination,
      l10n,
    );
    final destDetails = destination?.technicalDetails;
    final color = VerdictPresentation.colorOf(context, presentation.level);
    final shown =
        link.result.technicalDetails?.displayUrl ??
        UrlMasking.truncate(link.link.written, 80);
    return ListTile(
      key: ValueKey('link-${link.link.span.start}'),
      contentPadding: EdgeInsets.zero,
      leading: PictoBadge(icon: presentation.icon, color: color),
      title: Text(shown, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          presentation.label,
          if (destDetails != null)
            l10n.destLinkTile(
              destDetails.registrableDomain ?? destDetails.host,
            ),
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
      padding: const EdgeInsets.only(top: 4),
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

/// Bandeau « Pas de connexion » : la vérification en ligne, prioritaire,
/// n'a pas pu se faire ; seul le téléphone a vérifié.
class OfflineBanner extends StatelessWidget {
  const new({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = SafeLinkColors.of(context).warning;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PictoBadge(icon: Icons.cloud_off_rounded, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.offlineTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(l10n.offlineBody, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.onlineRetry),
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
