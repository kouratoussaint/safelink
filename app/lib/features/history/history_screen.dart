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
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Historique local des vérifications, filtrable par nature, niveau, période
/// et domaine.
class HistoryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _filter = const HistoryFilter();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _search.clear();
    setState(() => _filter = const HistoryFilter());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choice = ref.watch(historyChoiceProvider);
    final history = ref.watch(historyProvider);
    final entries = history.value ?? const <HistoryEntry>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.historyClearAll,
              onPressed: () => confirmClearHistory(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (history) {
          AsyncError() when !history.hasValue => _Centered(
            icon: Icons.error_outline,
            title: l10n.historyLoadError,
            action: FilledButton(
              onPressed: () => ref.invalidate(historyProvider),
              child: Text(l10n.historyRetry),
            ),
          ),
          AsyncLoading() when !history.hasValue => const Center(
            child: CircularProgressIndicator(),
          ),
          _ when entries.isEmpty => _EmptyState(choice: choice),
          _ => _buildList(context, entries, choice),
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<HistoryEntry> entries,
    HistoryChoice choice,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final shown = _filter.apply(entries, now);
    final rows = <Widget>[
      if (choice != HistoryChoice.enabled)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _ChoiceCard(choice: choice),
        ),
      _FilterBar(
        filter: _filter,
        search: _search,
        onChanged: (update) => setState(() => _filter = update(_filter)),
      ),
    ];
    if (shown.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(l10n.historyNoMatch, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetFilters,
                child: Text(l10n.historyClearFilters),
              ),
            ],
          ),
        ),
      );
    }
    String? day;
    for (final entry in shown) {
      final entryDay = historyDay(entry.analyzedAt, now, l10n);
      if (entryDay != day) {
        day = entryDay;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                entryDay,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
      rows.add(_EntryTile(entry));
    }
    rows.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Text(
          l10n.historyFooter(entries.length),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: SafeLinkColors.of(context).textSecondary,
          ),
        ),
      ),
    );
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const new({
    required this.filter,
    required this.search,
    required this.onChanged,
  });

  final HistoryFilter filter;
  final TextEditingController search;

  /// Applique une modification au filtre courant.
  final void Function(HistoryFilter Function(HistoryFilter) update) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active =
        filter.levels.length + (filter.period == HistoryPeriod.all ? 0 : 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.historyFilterKindLabel,
            container: true,
            child: SegmentedButton<AnalysisKind?>(
              segments: [
                ButtonSegment(value: null, label: Text(l10n.historyFilterAll)),
                ButtonSegment(
                  value: AnalysisKind.link,
                  label: Text(l10n.historyFilterLinks),
                ),
                ButtonSegment(
                  value: AnalysisKind.message,
                  label: Text(l10n.historyFilterMessages),
                ),
              ],
              selected: {filter.kind},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onChanged(
                (filter) => filter.copyWith(kind: () => selection.single),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l10n.historySearchLabel,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (query) =>
                onChanged((filter) => filter.copyWith(query: query)),
          ),
          Theme(
            // Pas de traits au-dessus et au-dessous du volet.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              leading: const ExcludeSemantics(child: Icon(Icons.tune)),
              title: Text(l10n.historyMoreFilters),
              subtitle: Text(l10n.historyActiveFilters(active)),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final level in RiskLevel.values.reversed)
                      FilterChip(
                        avatar: Icon(
                          VerdictPresentation.iconOf(level),
                          color: VerdictPresentation.colorOf(context, level),
                        ),
                        label: Text(
                          VerdictPresentation.levelLabel(l10n, level),
                        ),
                        selected: filter.levels.contains(level),
                        showCheckmark: false,
                        onSelected: (selected) => onChanged(
                          (filter) => filter.copyWith(
                            levels: selected
                                ? {...filter.levels, level}
                                : ({...filter.levels}..remove(level)),
                          ),
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final period in HistoryPeriod.values)
                      ChoiceChip(
                        label: Text(period.label(l10n)),
                        selected: filter.period == period,
                        showCheckmark: false,
                        onSelected: (_) => onChanged(
                          (filter) => filter.copyWith(period: period),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const new(this.entry);

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presentation = historyVerdict(entry, l10n);
    final color = VerdictPresentation.colorOf(context, entry.level);
    return ListTile(
      key: ValueKey('history-${entry.id}'),
      leading: ExcludeSemantics(
        child: Icon(VerdictPresentation.iconOf(entry.level), color: color),
      ),
      title: Text(
        historyTitle(entry, l10n),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${presentation.label} · ${historyTime(entry.analyzedAt)}',
      ),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: () => context.go(AppRoutes.historyEntry(entry.id)),
    );
  }
}

/// Proposition d'activer l'historique, ou rappel qu'il est désactivé.
class _ChoiceCard extends ConsumerWidget {
  const new({required this.choice});

  final HistoryChoice choice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final undecided = choice == HistoryChoice.undecided;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                undecided ? l10n.historyOfferTitle : l10n.historyDisabledTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(undecided ? l10n.historyOfferBody : l10n.historyDisabledBody),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (undecided)
                  TextButton(
                    onPressed: () => ref
                        .read(historyChoiceProvider.notifier)
                        .select(enabled: false),
                    child: Text(l10n.historyDecline),
                  ),
                FilledButton(
                  onPressed: () => ref
                      .read(historyChoiceProvider.notifier)
                      .select(enabled: true),
                  child: Text(l10n.historyEnable),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const new({required this.choice});

  final HistoryChoice choice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (choice != HistoryChoice.enabled) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_ChoiceCard(choice: choice)],
      );
    }
    return _Centered(
      icon: Icons.history,
      title: l10n.historyEmptyTitle,
      body: l10n.historyEmptyBody,
    );
  }
}

class _Centered extends StatelessWidget {
  const new({required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SafeLinkColors.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
