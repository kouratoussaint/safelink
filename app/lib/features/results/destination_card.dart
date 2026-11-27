import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Vraie destination d'un lien raccourci : adresse, verdict en image et
/// accès au détail. Si le service n'a pas répondu, le dit simplement.
class DestinationCard extends StatelessWidget {
  const new({required this.destination, super.key});

  /// Destination analysée ; `null` si elle n'a pas pu être connue.
  final UrlAnalysisResult? destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final destination = this.destination;
    final details = destination?.technicalDetails;
    if (destination == null || details == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PictoBadge(
                icon: Icons.visibility_off_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.destHidden, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ),
      );
    }
    final presentation = VerdictPresentation.forUrl(destination, l10n);
    final color = VerdictPresentation.colorOf(context, presentation.level);
    final domain = details.registrableDomain ?? details.host;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.alt_route,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.destTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: l10n.destSemantics(domain),
              child: ExcludeSemantics(
                child: AddressBar(
                  displayed: details.displayUrl,
                  domain: domain,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                PictoBadge(icon: presentation.icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VerdictPresentation.heroWord(l10n, presentation.level),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        presentation.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(l10n.destDetails),
              onPressed: () => context.push(
                AppRoutes.analysis,
                extra: AnalysisRequest(
                  AnalysisKind.link,
                  destination.url?.href ?? details.displayUrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
