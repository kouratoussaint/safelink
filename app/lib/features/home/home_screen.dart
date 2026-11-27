import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/core/widgets/info_card.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Accueil.
///
/// Dans cette version de développement, l'accueil présente la mission et
/// indique clairement que l'analyse n'est pas encore disponible : aucune
/// fonction future n'y est présentée comme opérationnelle.
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const SafeLinkWordmark(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.openSettingsTooltip,
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              l10n.tagline,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.homeTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              l10n.homeIntro,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            InfoCard(
              icon: Icons.construction_outlined,
              title: l10n.homeDevNoticeTitle,
              body: l10n.homeDevNoticeBody,
              accent: colors.info,
            ),
            const SizedBox(height: 24),
            Text(l10n.homeCommitmentsTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (icon, text) in [
              (Icons.volunteer_activism_outlined, l10n.homeCommitmentFree),
              (Icons.phone_android_outlined, l10n.homeCommitmentLocal),
              (Icons.fact_check_outlined, l10n.homeCommitmentHonest),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ExcludeSemantics(child: Icon(icon)),
                title: Text(text),
              ),
          ],
        ),
      ),
    );
  }
}
