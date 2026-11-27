import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_dialogs.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Paramètres de l'application.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final options = [
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.dark, l10n.themeDark),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionHeader(l10n.settingsAppearanceSection),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).select(value).ignore();
                }
              },
              child: Column(
                children: [
                  for (final (value, label) in options)
                    RadioListTile<ThemeMode>(value: value, title: Text(label)),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.tune),
              title: Text(l10n.settingsExpertSwitch),
              subtitle: Text(l10n.settingsExpertBody),
              value: ref.watch(expertModeProvider),
              onChanged: (value) =>
                  ref.read(expertModeProvider.notifier).select(enabled: value),
            ),
            const Divider(),
            _SectionHeader(l10n.settingsOnlineSection),
            SwitchListTile(
              secondary: const Icon(Icons.travel_explore),
              title: Text(l10n.settingsOnlineSwitch),
              subtitle: Text(
                ref.watch(googleEnabledProvider)
                    ? l10n.settingsOnlineGoogleSwitchBody
                    : l10n.settingsOnlineSwitchBody,
              ),
              value: ref.watch(onlineChoiceProvider) == OnlineChoice.enabled,
              onChanged: (value) => ref
                  .read(onlineChoiceProvider.notifier)
                  .select(enabled: value),
            ),
            const Divider(),
            _SectionHeader(l10n.settingsHistorySection),
            const _HistorySettings(),
            const Divider(),
            _SectionHeader(l10n.settingsAboutSection),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.settingsHelpTile),
              subtitle: Text(l10n.settingsHelpSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.help),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.settingsPrivacyTile),
              subtitle: Text(l10n.settingsPrivacySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.privacy),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.settingsAboutTile),
              subtitle: Text(l10n.settingsAboutSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.about),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.settingsPrivacyNote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SafeLinkColors.of(context).textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activation et effacement de l'historique.
class _HistorySettings extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(historyChoiceProvider) == HistoryChoice.enabled;
    final count = ref.watch(historyProvider).value?.length ?? 0;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.history),
          title: Text(l10n.settingsHistorySwitch),
          subtitle: Text(l10n.settingsHistorySwitchBody),
          value: enabled,
          onChanged: (value) async {
            if (value) {
              await ref
                  .read(historyChoiceProvider.notifier)
                  .select(enabled: true);
            } else {
              await confirmStopHistory(context, ref);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(l10n.settingsHistoryClear),
          subtitle: Text(l10n.settingsHistoryClearBody(count)),
          enabled: count > 0,
          onTap: () => confirmClearHistory(context, ref),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
