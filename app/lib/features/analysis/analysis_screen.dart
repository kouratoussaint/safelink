import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(analysis.hasValue ? l10n.resultTitle : l10n.analysisTitle),
      ),
      body: SafeArea(
        child: switch (analysis) {
          AsyncData(:final value) => switch (value) {
            LinkOutcome(:final result) => LinkResultView(
              result: result,
              footer: [ResultActions(outcome: value)],
            ),
            MessageOutcome(:final result) => MessageResultView(
              result: result,
              onOpenLink: (link) =>
                  context.push(AppRoutes.linkResult, extra: link.result),
              footer: [ResultActions(outcome: value)],
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
          _ => const _Running(),
        },
      ),
    );
  }
}

/// Résultat détaillé d'un lien repéré dans un message.
class LinkResultScreen extends StatelessWidget {
  const new({required this.result, super.key});

  final UrlAnalysisResult? result;

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
                footer: [ResultActions(outcome: LinkOutcome(result))],
              ),
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: l10n.analysisRunning,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.analysisRunning, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  l10n.analysisRunningBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SafeLinkColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
