import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/results/checklist.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expert = ref.watch(expertModeProvider);
    final offer = ref.watch(onlineChoiceProvider) == OnlineChoice.undecided;
    final presentation = VerdictPresentation.forUrl(result, l10n);
    final details = result.technicalDetails;
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
          signals: result.signals,
          actions: result.recommendedActions,
        ),
      ),
      if (details != null)
        AddressBar(
          displayed: details.displayUrl,
          domain: details.registrableDomain ?? details.host,
          color: VerdictPresentation.colorOf(context, presentation.level),
        ),
      if (PagePreviewCard.applies(result, ref)) PagePreviewCard(result: result),
      if (result.url != null && offer) const OnlineOfferCard(),
      ResultSection(
        title: l10n.sectionWhy,
        children: [
          ReasonList(
            signals: result.signals,
            expert: expert,
            emptyText: l10n.sectionWhyEmpty,
          ),
        ],
      ),
      ResultSection(
        title: l10n.sectionWhatToDo,
        children: [
          ActionGrid(actions: result.recommendedActions, expert: expert),
        ],
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expert = ref.watch(expertModeProvider);
    final offer = ref.watch(onlineChoiceProvider) == OnlineChoice.undecided;
    final message = result.message;
    final presentation = VerdictPresentation.forCombined(result.level, l10n);
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
          ],
          actions: result.recommendedActions,
        ),
      ),
      if (result.links.isNotEmpty && offer) const OnlineOfferCard(),
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
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: SafeLinkColors.of(context).textSecondary),
              ),
            ),
        ],
      ),
      if (firstLink != null && PagePreviewCard.applies(firstLink.result, ref))
        PagePreviewCard(result: firstLink.result),
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
      leading: PictoBadge(icon: presentation.icon, color: color),
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
