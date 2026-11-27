import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/help/help_widgets.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Exemples inventés à analyser : sur le téléphone seulement, jamais
/// enregistrés dans l'historique.
class ExamplesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final examples = [
      (AnalysisKind.link, l10n.exampleFakeSiteTitle, l10n.exampleFakeSiteText),
      (AnalysisKind.link, l10n.exampleShortTitle, l10n.exampleShortText),
      (
        AnalysisKind.message,
        l10n.exampleTransferTitle,
        l10n.exampleTransferText,
      ),
      (AnalysisKind.message, l10n.exampleUssdTitle, l10n.exampleUssdText),
      (AnalysisKind.message, l10n.examplePrizeTitle, l10n.examplePrizeText),
      (AnalysisKind.message, l10n.exampleNormalTitle, l10n.exampleNormalText),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.examplesTitle)),
      body: SafeArea(
        child: StaggeredList(
          children: [
            Text(l10n.examplesIntro, style: theme.textTheme.bodyLarge),
            for (final (kind, title, text) in examples)
              _ExampleTile(kind: kind, title: title, text: text),
          ],
        ),
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const new({required this.kind, required this.title, required this.text});

  final AnalysisKind kind;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.analysis,
          extra: AnalysisRequest(kind, text, example: true),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PictoBadge(
                icon: kind == AnalysisKind.link
                    ? Icons.link_rounded
                    : Icons.sms_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.exampleBadge,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}
