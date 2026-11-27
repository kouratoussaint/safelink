import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/info_card.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/help/help_widgets.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/features/share/shared_content.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Écran ouvert par « Partager → SafeLink » quand il y a un choix à faire
/// ([ChooseShared]) ou rien d'analysable ([RefuseShared]).
///
/// Les cas simples (un lien seul, un texte sans lien) n'y passent pas :
/// l'analyse démarre directement.
class ShareScreen extends StatelessWidget {
  const new({required this.plan, super.key});

  /// Plan décidé par `planShare` ; `null` si l'écran est rouvert sans
  /// partage (rien à vérifier).
  final SharePlan? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareTitle)),
      body: SafeArea(
        child: switch (plan) {
          final ChooseShared choose => _ChooseView(plan: choose),
          RefuseShared(:final content) => _RefuseView(content: content),
          AnalyzeShared() ||
          null => const _RefuseView(content: SharedNothing()),
        },
      ),
    );
  }
}

/// Lance l'analyse : l'écran de partage est remplacé, Retour ramène donc à
/// l'accueil.
void _analyze(BuildContext context, AnalysisKind kind, String text) =>
    context.go(AppRoutes.analysis, extra: AnalysisRequest(kind, text));

class _ChooseView extends StatefulWidget {
  const new({required this.plan});

  final ChooseShared plan;

  @override
  State<_ChooseView> createState() => _ChooseViewState();
}

class _ChooseViewState extends State<_ChooseView> {
  /// Vrai quand l'utilisateur a choisi « Le lien seulement » parmi
  /// plusieurs liens.
  bool _picking = false;

  ChooseShared get plan => widget.plan;

  void _linkOnly() {
    if (plan.links.length == 1) {
      _analyze(context, AnalysisKind.link, plan.links.single.url);
    } else {
      setState(() => _picking = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final links = plan.links;
    final wholeHint = l10n.shareWholeMessageHint(links.length);
    final linkHint = links.length == 1
        ? links.single.domain
        : l10n.shareLinkOnlyMany(links.length);
    final speech = [
      l10n.shareTitle,
      l10n.shareQuestion,
      '${l10n.shareWholeMessage} : $wholeHint',
      if (links.isNotEmpty) l10n.shareSpeechLinkOnly,
    ].map(spokenSentence).join(' ');
    return StaggeredList(
      children: [
        _Hero(
          icon: Icons.share_rounded,
          color: theme.colorScheme.primary,
          title: l10n.shareQuestion,
        ),
        Center(child: ListenButton(text: speech)),
        _ReceivedText(text: plan.content.text),
        if (plan.content.filesIgnored)
          InfoCard(
            icon: Icons.attach_file_rounded,
            title: l10n.shareFileIgnoredTitle,
            body: l10n.shareFileIgnored,
            accent: colors.info,
          ),
        if (plan.long)
          InfoCard(
            icon: Icons.content_cut_rounded,
            title: l10n.shareLongTitle,
            body: l10n.shareLong,
            accent: colors.info,
          ),
        _BigChoice(
          icon: Icons.sms_outlined,
          label: l10n.shareWholeMessage,
          hint: wholeHint,
          onTap: () =>
              _analyze(context, AnalysisKind.message, plan.messageText),
        ),
        if (links.isNotEmpty)
          _BigChoice(
            icon: Icons.link_rounded,
            label: l10n.shareLinkOnly,
            hint: linkHint,
            selected: _picking,
            onTap: _linkOnly,
          ),
        if (_picking)
          HelpSection(
            title: l10n.sharePickLink,
            children: [
              for (final (i, link) in links.indexed)
                _LinkChoice(
                  number: i + 1,
                  link: link,
                  onTap: () => _analyze(context, AnalysisKind.link, link.url),
                ),
            ],
          ),
      ],
    );
  }
}

class _RefuseView extends StatelessWidget {
  const new({required this.content});

  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final (icon, title, body) = switch (content) {
      SharedFiles(kind: SharedFileKind.image) => (
        Icons.image_outlined,
        l10n.shareNotYetTitle,
        l10n.shareFilesImage,
      ),
      SharedFiles(kind: SharedFileKind.video) => (
        Icons.videocam_outlined,
        l10n.shareNotYetTitle,
        l10n.shareFilesVideo,
      ),
      SharedFiles() => (
        Icons.insert_drive_file_outlined,
        l10n.shareNotYetTitle,
        l10n.shareFilesOther,
      ),
      SharedText() || SharedNothing() => (
        Icons.inbox_outlined,
        l10n.shareEmptyTitle,
        l10n.shareEmpty,
      ),
    };
    final files = content is SharedFiles;
    final speech = [
      title,
      body,
      if (files) ...[l10n.shareFilesWhat, l10n.shareFilesTip],
    ].map(spokenSentence).join(' ');
    return StaggeredList(
      children: [
        _Hero(
          icon: icon,
          color: colors.textSecondary,
          title: title,
          forbid: true,
        ),
        Text(
          body,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        Center(child: ListenButton(text: speech)),
        if (files)
          HelpSection(
            title: l10n.shareFilesWhat,
            children: [
              PictoRow(
                icon: Icons.content_copy_rounded,
                color: theme.colorScheme.primary,
                text: l10n.shareFilesTip,
              ),
            ],
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.home_outlined),
          label: Text(l10n.shareGoHome),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
    );
  }
}

/// Grand pictogramme animé, puis la question ou le titre.
class _Hero extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    required this.title,
    this.forbid = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final bool forbid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 8),
        Appear(
          child: HaloIcon(icon: icon, color: color, forbid: forbid),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Texte reçu, en citation, limité à quelques lignes.
class _ReceivedText extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    return Semantics(
      container: true,
      label: l10n.shareReceivedLabel,
      child: SoftCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.format_quote_rounded,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.trim(),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grande vignette de choix : pictogramme, libellé, précision.
class _BigChoice extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = SafeLinkColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: colors.cardShadow,
        ),
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: selected
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    PictoBadge(icon: icon, color: scheme.primary, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hint.isNotEmpty)
                            Text(
                              hint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ExcludeSemantics(
                      child: Icon(Icons.chevron_right, color: scheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un lien parmi plusieurs : numéro, lien masqué avec son domaine en gras.
class _LinkChoice extends StatelessWidget {
  const new({required this.number, required this.link, required this.onTap});

  final int number;
  final SharedLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: MergeSemantics(
                child: Semantics(
                  button: true,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        child: Text('$number'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HighlightedUrl(
                          displayed: link.displayed,
                          domain: link.domain,
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(Icons.chevron_right, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
