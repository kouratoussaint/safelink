import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/analysis/analysis_screen.dart' show Scanner;
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/short_links.dart';
import 'package:safelink/features/quick/quick_platform.dart';
import 'package:safelink/features/results/checks_strip.dart';
import 'package:safelink/features/results/link_identity_view.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/message_contents.dart';
import 'package:safelink/features/results/online_section.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/features/results/verdict_hero.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/features/share/share_screen.dart';
import 'package:safelink/features/share/shared_content.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Panneau rapide (ADR 0015), ouvert par la bulle, la tuile du volet ou la
/// notification de la bulle.
///
/// Une carte monte du bas de l'écran, par-dessus l'application en cours.
/// Elle vérifie le texte copié et ne montre que l'essentiel : verdict,
/// vrai site, quatre raisons au plus, trois gestes au plus. « Tout voir
/// dans SafeLink » ouvre la vérification en entier. Toucher à côté,
/// « Fermer » ou Retour ferme le panneau.
class QuickCheckScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// Raisons montrées au plus.
  static const maxReasons = 4;

  /// Gestes montrés au plus.
  static const maxActions = 3;

  @override
  ConsumerState<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends ConsumerState<QuickCheckScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _sheet,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );
  StreamSubscription<SharedContent>? _subscription;

  /// Ce que le panneau fait du texte copié ; `null` : lecture en cours.
  SharePlan? _plan;

  /// Vérification lancée.
  AnalysisRequest? _request;

  bool _closing = false;

  QuickPlatform get _platform => ref.read(quickPlatformProvider);

  @override
  void initState() {
    super.initState();
    _subscription = _platform.contents().listen(_receive);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_closing || _sheet.isAnimating || _sheet.isCompleted) return;
    if (reduceMotion(context)) {
      _sheet.value = 1;
    } else {
      _sheet.forward().ignore();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _sheet.dispose();
    super.dispose();
  }

  /// Nouveau texte copié : tout recommence.
  void _receive(SharedContent content) {
    final plan = planShare(content);
    setState(() {
      _plan = plan;
      _request = switch (plan) {
        AnalyzeShared(:final request) => request,
        _ => null,
      };
    });
  }

  void _choose(AnalysisKind kind, String text) =>
      setState(() => _request = AnalysisRequest(kind, text));

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (!reduceMotion(context)) await _sheet.reverse();
    await _platform.close();
  }

  Future<void> _openInApp(AnalysisRequest request) async {
    // Enregistrée par le panneau : l'application la remplace, sans doublon.
    final saved = ref.read(historyRecordProvider(request)).value;
    await _platform.openInApp(request, historyId: saved?.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final dark = theme.brightness == Brightness.dark;
    final body = switch ((_plan, _request)) {
      (_, final AnalysisRequest request) => _QuickAnalysis(
        key: ValueKey(request),
        request: request,
        onOpenInApp: () => _openInApp(request),
        onClose: _close,
      ),
      (final ChooseShared plan, null) => ShareChooser(
        key: ObjectKey(plan),
        plan: plan,
        compact: true,
        onAnalyze: _choose,
      ),
      (RefuseShared(:final content), null) => _QuickRefusal(
        key: ObjectKey(content),
        content: content,
        onClose: _close,
      ),
      _ => const _QuickReading(),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Icônes claires sur l'application assombrie, en haut ; en bas,
        // selon le fond du panneau.
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Toucher à côté du panneau le ferme.
              Positioned.fill(
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    // L'application du dessous reste visible en haut : on
                    // sait qu'on ne l'a pas quittée.
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      maxHeight:
                          (media.size.height - media.viewPadding.top) * 0.82,
                    ),
                    child: _Panel(
                      title: l10n.quickTitle,
                      onClose: _close,
                      bottomInset: media.viewPadding.bottom,
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte du panneau : en-tête SafeLink et « Fermer », puis le contenu, qui
/// défile s'il est trop long.
class _Panel extends StatelessWidget {
  const new({
    required this.title,
    required this.onClose,
    required this.bottomInset,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: SafeLinkColors.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 2),
              child: Row(
                children: [
                  const ExcludeSemantics(child: SafeLinkMark(size: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.quickClose,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
                child: AnimatedSize(
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colonne dont les blocs apparaissent l'un après l'autre.
class _Blocks extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, child) in children.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: Appear(index: i, child: child),
        ),
    ],
  );
}

/// Le texte copié est en train d'être lu (fenêtre pas encore au premier
/// plan).
class _QuickReading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context).quickReading;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(text, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rien à vérifier : rien de copié, texte illisible ou marqué secret.
class _QuickRefusal extends StatelessWidget {
  const new({required this.content, required this.onClose, super.key});

  final SharedContent content;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final (icon, body) = switch (content) {
      SharedNothing(sensitive: true) => (
        Icons.lock_outline,
        l10n.shareClipboardSecret,
      ),
      _ => (Icons.content_paste_off_outlined, l10n.shareClipboardEmpty),
    };
    final title = l10n.shareEmptyTitle;
    return _Blocks(
      children: [
        Center(
          child: HaloIcon(
            icon: icon,
            color: colors.textSecondary,
            forbid: true,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        Center(
          child: ListenButton(
            text: [title, body].map(spokenSentence).join(' '),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onClose,
          child: Text(l10n.quickClose),
        ),
      ],
    );
  }
}

/// Analyse en cours, puis son résultat résumé.
class _QuickAnalysis extends ConsumerWidget {
  const new({
    required this.request,
    required this.onOpenInApp,
    required this.onClose,
    super.key,
  });

  final AnalysisRequest request;
  final VoidCallback onOpenInApp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final analysis = ref.watch(analysisProvider(request));
    // Enregistre le résultat si l'historique est activé, comme dans
    // l'application.
    if (analysis.hasValue) ref.watch(historyRecordProvider(request));
    void retry() => ref.invalidate(analysisProvider(request));
    return switch (analysis) {
      AsyncData(:final value) => _QuickResult(
        outcome: value,
        onRetry: retry,
        onOpenInApp: onOpenInApp,
        onClose: onClose,
      ),
      AsyncError() => _Blocks(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              l10n.analysisErrorTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Text(l10n.analysisErrorBody, textAlign: TextAlign.center),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.analysisRetry),
            onPressed: retry,
          ),
        ],
      ),
      _ => _QuickRunning(
        online:
            ref.watch(analysisStageProvider(request)) == AnalysisStage.online,
        google: ref.watch(googleEnabledProvider),
      ),
    };
  }
}

class _QuickRunning extends StatelessWidget {
  const new({required this.online, required this.google});

  final bool online;

  /// Vrai si Google reçoit aussi le lien.
  final bool google;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = online ? l10n.analysisOnlineRunning : l10n.analysisRunning;
    final body = online
        ? (google
              ? l10n.analysisOnlineGoogleRunningBody
              : l10n.analysisOnlineRunningBody)
        : l10n.analysisRunningBody;
    return Semantics(
      liveRegion: true,
      label: title,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 112,
                child: FittedBox(child: Scanner(online: online)),
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SafeLinkColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Résultat résumé : verdict, vrai site, raisons et gestes principaux,
/// puis « Tout voir dans SafeLink » et « Fermer ».
class _QuickResult extends ConsumerWidget {
  const new({
    required this.outcome,
    required this.onRetry,
    required this.onOpenInApp,
    required this.onClose,
  });

  final AnalysisOutcome outcome;
  final VoidCallback onRetry;
  final VoidCallback onOpenInApp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expert = ref.watch(expertModeProvider);
    final List<Widget> top;
    final List<RiskSignal> signals;
    final List<RecommendedAction> actions;
    switch (outcome) {
      case LinkOutcome(:final result):
        final destination = outcome.destinationOf(result);
        final presentation = VerdictPresentation.forLinkWithDestination(
          result,
          destination,
          l10n,
        );
        signals = [...result.signals, ...?destination?.signals];
        // Comme dans l'application : les gestes de la destination quand
        // elle est plus grave.
        actions =
            destination != null && destination.level.rank > result.level.rank
            ? destination.recommendedActions
            : result.recommendedActions;
        final details = result.technicalDetails;
        final online = linkOnlineStatus(result, outcome.online);
        final url = result.url;
        final looked =
            online == OnlineStatus.done || online == OnlineStatus.unreachable;
        final identity = result.identity;
        top = [
          VerdictHero(
            compact: true,
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
              about: identity == null
                  ? null
                  : IdentityText.of(l10n, identity).spoken,
            ),
          ),
          ChecksStrip(online: online),
          if (online == OnlineStatus.unreachable)
            OfflineBanner(onRetry: onRetry),
          if (details != null)
            AddressBar(
              displayed: details.displayUrl,
              domain: details.registrableDomain ?? details.host,
              color: VerdictPresentation.colorOf(
                context,
                VerdictPresentation.forUrl(result, l10n).level,
              ),
            ),
          if (identity != null) LinkIdentityCard(identity: identity),
          if (url != null &&
              ShortLinkResolver.isShortener(url) &&
              (destination != null || looked))
            _Destination(destination: destination),
        ];
      case MessageOutcome(:final result):
        final presentation = VerdictPresentation.forCombined(
          outcome.level,
          l10n,
        );
        signals = [
          ...result.message.signals,
          for (final link in result.links) ...link.result.signals,
          for (final d in outcome.destinations.values) ...d.signals,
        ];
        actions = result.recommendedActions;
        final extraction = result.message.extraction;
        final contents = extraction == null
            ? const <(IconData, String)>[]
            : messageContents(l10n, extraction);
        top = [
          VerdictHero(
            compact: true,
            presentation: presentation,
            expert: expert,
            speech: verdictSpeech(
              l10n,
              presentation,
              signals: signals,
              actions: actions,
              about: contents.isEmpty
                  ? null
                  : l10n.contentsSemantics(
                      contents.map((c) => c.$2).join(', '),
                    ),
            ),
          ),
          ChecksStrip(online: outcome.online),
          if (outcome.online == OnlineStatus.unreachable)
            OfflineBanner(onRetry: onRetry),
          if (extraction != null &&
              result.message.verdict != MessageVerdict.invalidMessage)
            MessageContentsCard(extraction: extraction),
        ];
    }
    return _Blocks(
      children: [
        ...top,
        SectionBlock(
          title: l10n.sectionWhy,
          children: [
            ReasonList(
              signals: mainReasons(signals, expert: expert),
              expert: expert,
              emptyText: l10n.sectionWhyEmpty,
            ),
          ],
        ),
        if (actions.isNotEmpty)
          SectionBlock(
            title: l10n.sectionWhatToDo,
            children: [
              ActionGrid(
                actions: actions.take(QuickCheckScreen.maxActions).toList(),
                expert: expert,
              ),
            ],
          ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.open_in_full_rounded),
          label: Text(l10n.quickOpenInApp),
          onPressed: onOpenInApp,
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onClose,
          child: Text(l10n.quickClose),
        ),
      ],
    );
  }
}

/// Raisons montrées dans le panneau : sans doublon, les plus graves
/// d'abord, [QuickCheckScreen.maxReasons] au plus. Hors du mode expert,
/// les simples informations sont omises, comme dans l'application.
List<RiskSignal> mainReasons(List<RiskSignal> signals, {required bool expert}) {
  final unique = {for (final s in signals) '${s.code}|${s.evidence}': s}.values
      .where((s) => expert || s.severity.rank >= Severity.low.rank);
  final indexed = unique.indexed.toList()
    // Tri stable : à gravité égale, l'ordre du moteur est gardé.
    ..sort((a, b) {
      final bySeverity = b.$2.severity.rank.compareTo(a.$2.severity.rank);
      return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
    });
  return [
    for (final (_, signal) in indexed.take(QuickCheckScreen.maxReasons)) signal,
  ];
}

/// Vraie destination d'un lien raccourci, en une ligne.
class _Destination extends StatelessWidget {
  const new({required this.destination});

  /// Destination analysée ; `null` si elle n'a pas pu être connue.
  final UrlAnalysisResult? destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final destination = this.destination;
    final details = destination?.technicalDetails;
    if (destination == null || details == null) {
      return SoftCard(
        child: Row(
          children: [
            PictoBadge(
              icon: Icons.visibility_off_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.destHidden, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      );
    }
    final presentation = VerdictPresentation.forUrl(destination, l10n);
    final color = VerdictPresentation.colorOf(context, presentation.level);
    final domain = details.registrableDomain ?? details.host;
    return SoftCard(
      child: MergeSemantics(
        child: Row(
          children: [
            PictoBadge(icon: Icons.alt_route, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.destLinkTile(domain),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${VerdictPresentation.heroWord(l10n, presentation.level)}'
                    ' · ${presentation.label}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
