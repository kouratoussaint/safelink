import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/help/help_widgets.dart';
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

/// Raccourcis du système : bulle flottante, tuile du volet et action de
/// sélection de texte (ADR 0014).
class _ShortcutSettings extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ShortcutSettings> createState() => _ShortcutSettingsState();
}

class _ShortcutSettingsState extends ConsumerState<_ShortcutSettings> {
  late final AppLifecycleListener _lifecycle;

  /// Le réglage Android a été ouvert pour autoriser la bulle : au retour,
  /// l'activer si l'autorisation est donnée.
  bool _awaitingPermission = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onResume() async {
    if (_awaitingPermission) {
      _awaitingPermission = false;
      final l10n = AppLocalizations.of(context);
      final platform = ref.read(shortcutsProvider);
      final state = await platform.bubbleState();
      if (state.permitted) {
        await platform.setBubble(enabled: true);
        _snack(l10n.bubbleEnabled);
      } else {
        _snack(l10n.bubbleNotPermitted);
      }
    }
    ref.invalidate(bubbleStateProvider);
  }

  Future<void> _toggleBubble({required bool enabled}) async {
    final l10n = AppLocalizations.of(context);
    final platform = ref.read(shortcutsProvider);
    if (!enabled) {
      await platform.setBubble(enabled: false);
      ref.invalidate(bubbleStateProvider);
      return;
    }
    final state = await platform.bubbleState();
    if (state.permitted) {
      await platform.setBubble(enabled: true);
      ref.invalidate(bubbleStateProvider);
      _snack(l10n.bubbleEnabled);
      return;
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => const _BubbleDialog(),
    );
    if (go != true) return;
    _awaitingPermission = true;
    if (!await platform.openOverlaySettings()) {
      _awaitingPermission = false;
      _snack(l10n.bubbleNotPermitted);
    }
  }

  Future<void> _addTile() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(shortcutsProvider).requestTile();
    _snack(switch (result) {
      TileRequest.added => l10n.settingsTileAdded,
      TileRequest.already => l10n.settingsTileAlready,
      TileRequest.refused => l10n.settingsTileRefused,
      TileRequest.unsupported => l10n.settingsTileManual,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SafeLinkColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final canRequest = ref.watch(canRequestTileProvider).value ?? false;
    final bubble = ref.watch(bubbleStateProvider).value ?? const BubbleState();
    final bubbleBadge = PictoBadge(
      icon: Icons.bubble_chart_outlined,
      color: bubble.supported ? colors.warning : colors.textSecondary,
      size: 40,
    );
    return GroupedCard(
      children: [
        if (bubble.supported)
          SwitchListTile(
            secondary: bubbleBadge,
            title: Text(l10n.settingsBubbleTitle),
            subtitle: Text(l10n.settingsBubbleBody),
            value: bubble.enabled,
            onChanged: (value) => _toggleBubble(enabled: value),
          )
        else
          CardRow(
            leading: bubbleBadge,
            title: l10n.settingsBubbleTitle,
            subtitle: l10n.settingsBubbleUnsupported,
          ),
        CardRow(
          leading: PictoBadge(
            icon: Icons.swipe_down_alt_rounded,
            color: primary,
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
                  onPressed: _addTile,
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

/// Explique, en trois pictogrammes, le réglage Android à activer pour la
/// bulle, et ce qu'elle ne fait pas.
class _BubbleDialog extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return AlertDialog(
      title: Text(l10n.bubbleDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PictoRow(
              icon: Icons.settings_outlined,
              color: primary,
              text: l10n.bubbleDialogStep1,
            ),
            PictoRow(
              icon: Icons.toggle_on_outlined,
              color: primary,
              text: l10n.bubbleDialogStep2,
            ),
            PictoRow(
              icon: Icons.bubble_chart_outlined,
              color: primary,
              text: l10n.bubbleDialogStep3,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bubbleDialogNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SafeLinkColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.bubbleDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.bubbleDialogOpen),
        ),
      ],
    );
  }
}
