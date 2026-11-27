import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Demande confirmation, puis efface tout l'historique.
Future<void> confirmClearHistory(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final count = ref.read(historyProvider).value?.length ?? 0;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.historyClearAllTitle),
      content: Text(l10n.historyClearAllBody(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.historyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.historyClearAll),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(historyProvider.notifier).clear();
  if (context.mounted) _notify(context, l10n.historyCleared);
}

/// Demande confirmation avant de supprimer une vérification ; vrai si elle
/// a été supprimée.
Future<bool> confirmDeleteEntry(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.historyDeleteTitle),
      content: Text(l10n.historyDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.historyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.historyDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(historyProvider.notifier).delete(id);
  if (context.mounted) _notify(context, l10n.historyDeleted);
  return true;
}

/// Avertit avant de conserver le lien complet ou le texte d'un message ;
/// vrai si l'utilisateur confirme.
Future<bool> confirmKeepContent(BuildContext context, AnalysisKind kind) async {
  final l10n = AppLocalizations.of(context);
  final isLink = kind == AnalysisKind.link;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        isLink ? l10n.historyKeepUrlTitle : l10n.historyKeepTextTitle,
      ),
      content: Text(
        isLink ? l10n.historyKeepUrlBody : l10n.historyKeepTextBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.historyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.historyKeepConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Désactive l'historique en proposant d'effacer ce qui est enregistré.
Future<void> confirmStopHistory(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final count = ref.read(historyProvider).value?.length ?? 0;
  final choice = ref.read(historyChoiceProvider.notifier);
  if (count == 0) {
    await choice.select(enabled: false);
    return;
  }
  final clear = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.historyStopTitle),
      content: Text(l10n.historyStopBody(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.historyCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.historyStopOnly),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.historyStopAndClear),
        ),
      ],
    ),
  );
  if (clear == null) return;
  await choice.select(enabled: false);
  if (clear) {
    await ref.read(historyProvider.notifier).clear();
    if (context.mounted) _notify(context, l10n.historyCleared);
  }
}
