import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_dialogs.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Sous un résultat : proposition d'activer l'historique, ou état de
/// l'enregistrement de cette vérification.
class HistoryPanel extends ConsumerWidget {
  const new({required this.request, super.key});

  /// Demande dont le résultat est affiché.
  final AnalysisRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choice = ref.watch(historyChoiceProvider);
    final record = ref.watch(historyRecordProvider(request));
    final recorder = ref.read(historyRecordProvider(request).notifier);
    final isLink = request.kind == AnalysisKind.link;

    if (choice == HistoryChoice.undecided) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.historyOfferTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.historyOfferBody),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => ref
                          .read(historyChoiceProvider.notifier)
                          .select(enabled: false),
                      child: Text(l10n.historyDecline),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await ref
                            .read(historyChoiceProvider.notifier)
                            .select(enabled: true);
                        await recorder.save();
                      },
                      child: Text(l10n.historyEnable),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final entry = record.value;
    if (choice == HistoryChoice.disabled || entry == null) {
      return const SizedBox.shrink();
    }
    final kept = entry.content != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.history,
                      color: SafeLinkColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kept
                          ? l10n.historySavedWithContent
                          : isLink
                          ? l10n.historySavedLink
                          : l10n.historySavedMessage,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (kept)
                    TextButton(
                      onPressed: () => recorder.keepContent(keep: false),
                      child: Text(l10n.historyForgetContent),
                    )
                  else
                    TextButton(
                      onPressed: () async {
                        if (await confirmKeepContent(context, request.kind)) {
                          await recorder.keepContent(keep: true);
                        }
                      },
                      child: Text(
                        isLink ? l10n.historyKeepUrl : l10n.historyKeepText,
                      ),
                    ),
                  TextButton(
                    onPressed: () async {
                      await recorder.remove();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.historyRemoved)),
                        );
                    },
                    child: Text(l10n.historyRemove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
