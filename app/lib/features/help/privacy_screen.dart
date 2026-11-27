import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/help/help_widgets.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Confidentialité : ce qui reste sur le téléphone, ce qui est envoyé et à
/// qui, ce qui n'arrive jamais. Interrupteur de la vérification en ligne.
class PrivacyScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final primary = theme.colorScheme.primary;
    final google = ref.watch(googleEnabledProvider);
    final online = ref.watch(onlineChoiceProvider) == OnlineChoice.enabled;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: SafeArea(
        child: StaggeredList(
          children: [
            Text(l10n.privacyIntro, style: theme.textTheme.bodyLarge),
            HelpSection(
              title: l10n.privacyPhoneTitle,
              children: [
                PictoRow(
                  icon: Icons.sms_outlined,
                  color: colors.success,
                  text: l10n.privacyPhone1,
                ),
                PictoRow(
                  icon: Icons.history,
                  color: colors.success,
                  text: l10n.privacyPhone2,
                ),
                PictoRow(
                  icon: Icons.tune,
                  color: colors.success,
                  text: l10n.privacyPhone3,
                ),
              ],
            ),
            HelpSection(
              title: l10n.privacySentTitle,
              children: [
                PictoRow(
                  icon: Icons.dns_outlined,
                  color: primary,
                  text: l10n.privacySentDns,
                ),
                PictoRow(
                  icon: Icons.event_outlined,
                  color: primary,
                  text: l10n.privacySentRegistry,
                ),
                if (google) ...[
                  PictoRow(
                    icon: Icons.fingerprint,
                    color: primary,
                    text: l10n.privacySentSafeBrowsing,
                  ),
                  PictoRow(
                    icon: Icons.photo_camera_outlined,
                    color: primary,
                    text: l10n.privacySentPhoto,
                  ),
                ],
                PictoRow(
                  icon: Icons.alt_route,
                  color: primary,
                  text: l10n.privacySentShort,
                ),
                Text(
                  l10n.privacySentSecure,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsOnlineSwitch),
                  value: online,
                  onChanged: (value) => ref
                      .read(onlineChoiceProvider.notifier)
                      .select(enabled: value),
                ),
              ],
            ),
            HelpSection(
              title: l10n.privacyNeverTitle,
              children: [
                PictoRow(
                  icon: Icons.person_off_outlined,
                  color: colors.danger,
                  forbid: true,
                  text: l10n.privacyNever1,
                ),
                PictoRow(
                  icon: Icons.sms_outlined,
                  color: colors.danger,
                  forbid: true,
                  text: l10n.privacyNever2,
                ),
                PictoRow(
                  icon: Icons.sell_outlined,
                  color: colors.danger,
                  forbid: true,
                  text: l10n.privacyNever3,
                ),
              ],
            ),
            HelpSection(
              title: l10n.privacyPermissionTitle,
              children: [
                PictoRow(
                  icon: Icons.wifi,
                  color: primary,
                  text: l10n.privacyPermission,
                ),
                PictoRow(
                  icon: Icons.code,
                  color: primary,
                  text: l10n.privacyOpenSource,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.settingsAboutTile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.about),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
