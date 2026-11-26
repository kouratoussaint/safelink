import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/info_card.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Conseils de prévention, entièrement locaux : aucune alerte « temps réel ».
class TipsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final tips = [
      (Icons.pin_outlined, l10n.tipCodesTitle, l10n.tipCodesBody),
      (Icons.timer_outlined, l10n.tipUrgencyTitle, l10n.tipUrgencyBody),
      (Icons.call_outlined, l10n.tipChannelTitle, l10n.tipChannelBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              l10n.tipsIntro,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (final (icon, title, body) in tips) ...[
              InfoCard(icon: icon, title: title, body: body),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.tipsMoreSoon,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
