import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_panel.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/results/checks_strip.dart';
import 'package:safelink/features/results/online_section.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Analyse d'une demande, puis son résultat.
///
/// Pendant l'analyse, un indicateur sans fausse progression ; en cas
/// d'erreur, aucun résultat n'est inventé : l'écran propose « Réessayer ».
class AnalysisScreen extends ConsumerWidget {
  const new({required this.request, super.key});

  /// Demande à analyser ; nulle si l'écran est rouvert sans demande.
  final AnalysisRequest? request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final request = this.request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.analysisTitle)),
        body: _Message(
          icon: Icons.search_off,
          title: l10n.analysisMissing,
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(l10n.analysisBackHome),
          ),
        ),
      );
    }
    final analysis = ref.watch(analysisProvider(request));
    // Enregistre le résultat si l'historique est activé, même si le panneau
    // du bas n'est pas encore affiché.
    if (analysis.hasValue) ref.watch(historyRecordProvider(request));
    return Scaffold(
      appBar: AppBar(
        title: Text(analysis.hasValue ? l10n.resultTitle : l10n.analysisTitle),
      ),
      body: SafeArea(
        child: switch (analysis) {
          AsyncData(:final value) => switch (value) {
            LinkOutcome(:final result) => LinkResultView(
              result: result,
              destination: value.destinationOf(result),
              online: linkOnlineStatus(result, value.online),
              checks: request.example ? OnlineStatus.notApplicable : null,
              onRetry: () => ref.invalidate(analysisProvider(request)),
              header: [if (request.example) const ExampleBanner()],
              footer: [
                if (!request.example) HistoryPanel(request: request),
                ResultActions(outcome: value),
              ],
            ),
            MessageOutcome(:final result) => MessageResultView(
              result: result,
              destinations: value.destinations,
              online: value.online,
              checks: request.example ? OnlineStatus.notApplicable : null,
              onRetry: () => ref.invalidate(analysisProvider(request)),
              onOpenLink: (link) => context.push(
                AppRoutes.linkResult,
                extra: (
                  link.result,
                  linkOnlineStatus(link.result, value.online),
                  value.destinationOf(link.result),
                ),
              ),
              header: [if (request.example) const ExampleBanner()],
              footer: [
                if (!request.example) HistoryPanel(request: request),
                ResultActions(outcome: value),
              ],
            ),
          },
          AsyncError() => _Message(
            icon: Icons.error_outline,
            title: l10n.analysisErrorTitle,
            body: l10n.analysisErrorBody,
            action: FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.analysisRetry),
              onPressed: () => ref.invalidate(analysisProvider(request)),
            ),
          ),
          _ => _Running(
            stage: ref.watch(analysisStageProvider(request)),
            google: ref.watch(googleEnabledProvider),
            // Un lien est aussi vérifié en ligne, si c'est permis : l'étape
            // est montrée dès le début.
            onlinePlanned:
                request.kind == AnalysisKind.link &&
                !request.example &&
                ref.watch(onlineChoiceProvider) == OnlineChoice.enabled,
          ),
        },
      ),
    );
  }
}

/// Résultat détaillé d'un lien repéré dans un message.
class LinkResultScreen extends StatelessWidget {
  const new({
    required this.result,
    this.online = OnlineStatus.notRequested,
    this.destination,
    super.key,
  });

  final UrlAnalysisResult? result;

  /// Vraie destination analysée, si le lien est raccourci.
  final UrlAnalysisResult? destination;

  /// État de la vérification en ligne de ce lien.
  final OnlineStatus online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = this.result;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultLinkTitle)),
      body: SafeArea(
        child: result == null
            ? _Message(
                icon: Icons.search_off,
                title: l10n.analysisMissing,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(l10n.analysisBackHome),
                ),
              )
            : LinkResultView(
                result: result,
                destination: destination,
                online: online,
                footer: [
                  ResultActions(
                    outcome: LinkOutcome(
                      result,
                      online: online,
                      destinations: {
                        if (destination != null && result.url != null)
                          result.url!.href: destination!,
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const new({
    required this.stage,
    required this.google,
    this.onlinePlanned = false,
  });

  final AnalysisStage stage;

  /// Vrai si Google reçoit aussi le lien.
  final bool google;

  /// La vérification en ligne suivra celle du téléphone.
  final bool onlinePlanned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final online = stage == AnalysisStage.online;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: online ? l10n.analysisOnlineRunning : l10n.analysisRunning,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Scanner(online: online),
                const SizedBox(height: 20),
                Text(
                  online ? l10n.analysisOnlineRunning : l10n.analysisRunning,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  online
                      ? (google
                            ? l10n.analysisOnlineGoogleRunningBody
                            : l10n.analysisOnlineRunningBody)
                      : l10n.analysisRunningBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SafeLinkColors.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    CheckChip(
                      icon: Icons.phone_android_rounded,
                      label: l10n.analysisStepPhone,
                      done: online,
                      working: !online,
                    ),
                    if (online || onlinePlanned)
                      CheckChip(
                        icon: Icons.public_rounded,
                        label: l10n.analysisStepOnline,
                        done: false,
                        working: online,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animation d'analyse : un faisceau tourne autour d'un bouclier, comme un
/// radar ; pendant la vérification en ligne, un globe remplace le
/// téléphone.
class Scanner extends StatefulWidget {
  const new({required this.online, super.key});

  final bool online;

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _ScanPainter(
            t: _controller.value,
            color: scheme.primary,
            track: scheme.outlineVariant,
          ),
          child: child,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.online
                  ? Icons.travel_explore_rounded
                  : Icons.shield_rounded,
              key: ValueKey(widget.online),
              size: 56,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  new({required this.t, required this.color, required this.track});

  final double t;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = 2 * math.pi * t - math.pi / 2;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = track,
      )
      // Onde qui s'élargit.
      ..drawCircle(
        center,
        radius * (0.45 + 0.55 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.35 * (1 - t)),
      )
      // Faisceau qui tourne.
      ..drawArc(
        rect,
        start,
        math.pi / 2,
        true,
        Paint()
          ..shader = SweepGradient(
            endAngle: math.pi / 2,
            colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.28)],
            transform: GradientRotation(start),
          ).createShader(rect),
      )
      ..drawArc(
        rect,
        start + math.pi / 2 - 0.08,
        0.08,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.t != t || old.color != color || old.track != track;
}

class _Message extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.action,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 48, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 24),
        Center(child: action),
      ],
    );
  }
}
