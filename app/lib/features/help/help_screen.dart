import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/features/help/help_widgets.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Aide : comment faire en trois gestes, ce que veut dire chaque couleur,
/// ce que SafeLink ne peut pas faire, et des exemples à essayer.
class HelpScreen extends StatelessWidget {
  const new({super.key});

  static const List<RiskLevel> _levels = [
    RiskLevel.danger,
    RiskLevel.attention,
    RiskLevel.uncertain,
    RiskLevel.nothingObvious,
    RiskLevel.notAnalyzable,
  ];

  static String _meaning(AppLocalizations l10n, RiskLevel level) =>
      switch (level) {
        RiskLevel.danger => l10n.helpLegendDanger,
        RiskLevel.attention => l10n.helpLegendAttention,
        RiskLevel.uncertain => l10n.helpLegendUncertain,
        RiskLevel.nothingObvious => l10n.helpLegendNothing,
        RiskLevel.notAnalyzable => l10n.helpLegendNotAnalyzable,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final steps = [
      (Icons.content_copy_rounded, l10n.helpStep1),
      (Icons.content_paste_rounded, l10n.helpStep2),
      (Icons.volume_up_rounded, l10n.helpStep3),
    ];
    final share = [
      (Icons.touch_app_outlined, l10n.helpShare1),
      (Icons.share_rounded, l10n.helpShare2),
      (Icons.text_fields_rounded, l10n.helpShareSelect),
      (Icons.swipe_down_alt_rounded, l10n.helpShareTile),
      (Icons.bubble_chart_outlined, l10n.helpShareBubble),
      (Icons.content_copy_rounded, l10n.helpShare3),
    ];
    final limits = [
      (Icons.gpp_maybe_outlined, l10n.helpLimit1),
      (Icons.person_off_outlined, l10n.helpLimit2),
      (Icons.photo_camera_outlined, l10n.helpLimit3),
      (Icons.translate, l10n.helpLimit4),
    ];
    final speech = [
      l10n.helpHowTitle,
      for (final (i, (_, text)) in steps.indexed) '${i + 1}. $text',
      l10n.helpShareTitle,
      for (final (_, text) in share) text,
      l10n.helpLegendTitle,
      for (final level in _levels)
        '${VerdictPresentation.heroWord(l10n, level)} ${_meaning(l10n, level)}',
    ].map(spokenSentence).join(' ');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: SafeArea(
        child: StaggeredList(
          children: [
            Center(child: ListenButton(text: speech)),
            HelpSection(
              title: l10n.helpHowTitle,
              children: [
                for (final (i, (icon, text)) in steps.indexed)
                  PictoRow(
                    icon: icon,
                    color: primary,
                    title: '${i + 1}',
                    text: text,
                  ),
              ],
            ),
            HelpSection(
              title: l10n.helpShareTitle,
              children: [
                for (final (icon, text) in share)
                  PictoRow(icon: icon, color: primary, text: text),
              ],
            ),
            HelpSection(
              title: l10n.helpLegendTitle,
              children: [
                for (final level in _levels)
                  PictoRow(
                    icon: VerdictPresentation.iconOf(level),
                    color: VerdictPresentation.colorOf(context, level),
                    title: VerdictPresentation.heroWord(l10n, level),
                    text: _meaning(l10n, level),
                  ),
              ],
            ),
            HelpSection(
              title: l10n.helpExamplesTitle,
              children: [
                Text(l10n.helpExamplesBody, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.helpExamplesTitle),
                  onPressed: () => context.go(AppRoutes.examples),
                ),
                const SizedBox(height: 8),
              ],
            ),
            HelpSection(
              title: l10n.helpLimitsTitle,
              children: [
                for (final (icon, text) in limits)
                  PictoRow(
                    icon: icon,
                    color: theme.colorScheme.onSurfaceVariant,
                    text: text,
                  ),
              ],
            ),
            HelpSection(
              title: l10n.helpMoreTitle,
              children: [
                _LinkTile(
                  icon: Icons.lightbulb_outline,
                  label: l10n.helpTipsLink,
                  onTap: () => context.go(AppRoutes.tips),
                ),
                _LinkTile(
                  icon: Icons.lock_outline,
                  label: l10n.helpPrivacyLink,
                  onTap: () => context.go(AppRoutes.privacy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
