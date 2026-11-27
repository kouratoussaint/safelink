import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Adresse inconnue : jamais d'écran technique, toujours une sortie.
class NotFoundScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.explore_off_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.notFoundTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l10n.notFoundAction),
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
