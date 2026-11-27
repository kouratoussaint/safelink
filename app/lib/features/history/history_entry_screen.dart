import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_dialogs.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/history/history_presentation.dart';
import 'package:safelink/features/results/result_widgets.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Fiche d'une vérification enregistrée.
class HistoryEntryScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  /// Identifiant de la vérification.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(historyProvider).value ?? const [];
    final entry = entries.where((e) => e.id == id).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyEntryTitle),
        actions: [
          if (entry != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.historyDelete,
              onPressed: () async {
                if (await confirmDeleteEntry(context, ref, id) &&
                    context.mounted) {
                  context.go(AppRoutes.history);
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: entry == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.historyNoMatch, textAlign: TextAlign.center),
                ),
              )
            : _EntryDetails(entry),
      ),
    );
  }
}

class _EntryDetails extends ConsumerWidget {
  const new(this.entry);

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final details = entry.details;
    final isLink = entry.kind == AnalysisKind.link;
    final content = entry.content;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VerdictHeader(presentation: historyVerdict(entry, l10n)),
        const SizedBox(height: 16),
        ResultSection(
          title: l10n.historyEntryInfo,
          children: [
            DetailRow(
              label: l10n.historyEntryDate,
              value: formatAnalysisDate(entry.analyzedAt),
            ),
            DetailRow(
              label: l10n.historyEntryKind,
              value: isLink ? l10n.homeModeLink : l10n.homeModeMessage,
            ),
            if (isLink && details != null)
              DetailRow(
                label: l10n.historyEntryDomain,
                value: details.domain ?? l10n.historyInvalidLink,
              ),
            DetailRow(label: l10n.historyEntryRules, value: entry.rulesVersion),
          ],
        ),
        const SizedBox(height: 12),
        if (details == null)
          ResultSection(
            title: l10n.historyUnreadable,
            children: [Text(l10n.historyUnreadableBody)],
          )
        else ...[
          ResultSection(
            title: l10n.historyEntryReasons,
            children: details.signals.isEmpty
                ? [Text(l10n.historyEntryNoReasons)]
                : [for (final signal in details.signals) _SignalRow(signal)],
          ),
          if (!isLink) ...[
            const SizedBox(height: 12),
            ResultSection(
              title: l10n.historyEntryLinks,
              children: details.links.isEmpty
                  ? [Text(l10n.sectionLinksEmpty)]
                  : [for (final link in details.links) _LinkRow(link)],
            ),
          ],
        ],
        if (content != null) ...[
          const SizedBox(height: 12),
          ResultSection(
            title: isLink ? l10n.historyKeptUrl : l10n.historyKeptText,
            children: [
              SelectionArea(
                child: Text(content, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: Text(l10n.historyReanalyze),
                    onPressed: () => context.go(
                      AppRoutes.analysis,
                      extra: AnalysisRequest(entry.kind, content),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(historyProvider.notifier)
                        .setContent(entry.id, null),
                    child: Text(l10n.historyForgetContent),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.historyEntryStale,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: SafeLinkColors.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SignalRow extends StatelessWidget {
  const new(this.signal);

  final StoredSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final level = VerdictPresentation.levelOfSeverity(signal.severity);
    final color = VerdictPresentation.colorOf(context, level);
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const new(this.link);

  final StoredLink link;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presentation = VerdictPresentation.forUrlVerdict(link.verdict, l10n);
    final color = VerdictPresentation.colorOf(context, presentation.level);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(child: Icon(presentation.icon, color: color)),
      title: Text(link.domain ?? l10n.historyInvalidLink),
      subtitle: Text(presentation.label, style: TextStyle(color: color)),
    );
  }
}
