import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_dialogs.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/share/shortcuts.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Paramètres de l'application.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final mode = ref.watch(themeModeProvider);
    final options = [
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.dark, l10n.themeDark),
    ];
    return Scaffold(
      appBar: TabAppBar(title: l10n.settingsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            GroupLabel(l10n.settingsOnlineSection),
            GroupedCard(
              children: [
                SwitchListTile(
                  secondary: PictoBadge(
                    icon: Icons.travel_explore,
                    color: theme.colorScheme.primary,
                    size: 40,
                  ),
                  title: Text(l10n.settingsOnlineSwitch),
                  subtitle: Text(
                    ref.watch(googleEnabledProvider)
                        ? l10n.settingsOnlineGoogleSwitchBody
                        : l10n.settingsOnlineSwitchBody,
                  ),
                  value:
                      ref.watch(onlineChoiceProvider) == OnlineChoice.enabled,
                  onChanged: (value) => ref
                      .read(onlineChoiceProvider.notifier)
                      .select(enabled: value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GroupLabel(l10n.settingsHistorySection),
            const _HistorySettings(),
            const SizedBox(height: 20),
            GroupLabel(l10n.settingsAppearanceSection),
            GroupedCard(
              children: [
                RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(themeModeProvider.notifier)
                          .select(value)
                          .ignore();
                    }
                  },
                  child: Column(
                    children: [
                      for (final (value, label) in options)
                        RadioListTile<ThemeMode>(
                          value: value,
                          title: Text(label),
                        ),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: PictoBadge(
                    icon: Icons.tune,
                    color: colors.info,
                    size: 40,
                  ),
                  title: Text(l10n.settingsExpertSwitch),
                  subtitle: Text(l10n.settingsExpertBody),
                  value: ref.watch(expertModeProvider),
                  onChanged: (value) => ref
                      .read(expertModeProvider.notifier)
                      .select(enabled: value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GroupLabel(l10n.settingsShortcutsSection),
            const _ShortcutSettings(),
            const SizedBox(height: 20),
            GroupLabel(l10n.settingsAboutSection),
            GroupedCard(
              children: [
                CardRow(
                  leading: PictoBadge(
                    icon: Icons.help_outline,
                    color: colors.textSecondary,
                    size: 40,
                  ),
                  title: l10n.settingsHelpTile,
                  subtitle: l10n.settingsHelpSubtitle,
                  onTap: () => context.go(AppRoutes.help),
                ),
                CardRow(
                  leading: PictoBadge(
                    icon: Icons.lock_outline,
                    color: colors.textSecondary,
                    size: 40,
                  ),
                  title: l10n.settingsPrivacyTile,
                  subtitle: l10n.settingsPrivacySubtitle,
                  onTap: () => context.go(AppRoutes.privacy),
                ),
                CardRow(
                  leading: PictoBadge(
                    icon: Icons.info_outline,
                    color: colors.textSecondary,
                    size: 40,
                  ),
                  title: l10n.settingsAboutTile,
                  subtitle: l10n.settingsAboutSubtitle,
                  onTap: () => context.go(AppRoutes.about),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                l10n.settingsPrivacyNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
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
    final colors = SafeLinkColors.of(context);
    return GroupedCard(
      children: [
        SwitchListTile(
          secondary: PictoBadge(
            icon: Icons.history,
            color: colors.info,
            size: 40,
          ),
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
          leading: PictoBadge(
            icon: Icons.delete_sweep_outlined,
            color: colors.danger,
            size: 40,
          ),
          title: Text(l10n.settingsHistoryClear),
          subtitle: Text(l10n.settingsHistoryClearBody(count)),
          enabled: count > 0,
          onTap: () => confirmClearHistory(context, ref),
        ),
      ],
    );
  }
}

/// Raccourcis du système : tuile du volet et action de sélection de texte
/// (ADR 0014).
class _ShortcutSettings extends ConsumerWidget {
  const new();

  Future<void> _addTile(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(shortcutsProvider).requestTile();
    final text = switch (result) {
      TileRequest.added => l10n.settingsTileAdded,
      TileRequest.already => l10n.settingsTileAlready,
      TileRequest.refused => l10n.settingsTileRefused,
      TileRequest.unsupported => l10n.settingsTileManual,
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = SafeLinkColors.of(context);
    final canRequest = ref.watch(canRequestTileProvider).value ?? false;
    return GroupedCard(
      children: [
        CardRow(
          leading: PictoBadge(
            icon: Icons.swipe_down_alt_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          title: l10n.settingsTileTitle,
          subtitle: canRequest
              ? l10n.settingsTileBody
              : l10n.settingsTileManual,
          trailing: canRequest
              ? FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _addTile(context, ref),
                  child: Text(l10n.settingsTileAdd),
                )
              : null,
        ),
        CardRow(
          leading: PictoBadge(
            icon: Icons.text_fields_rounded,
            color: colors.info,
            size: 40,
          ),
          title: l10n.settingsSelectionTitle,
          subtitle: l10n.settingsSelectionBody,
        ),
      ],
    );
  }
}
