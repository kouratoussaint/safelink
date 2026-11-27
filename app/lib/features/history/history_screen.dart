import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Historique local des vérifications.
///
/// Aucun enregistrement n'existe tant que l'analyse n'est pas disponible ;
/// l'écran explique le fonctionnement prévu, désactivé par défaut.
class HistoryScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.history_toggle_off,
                    size: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.historyEmptyTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.historyEmptyBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SafeLinkColors.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
