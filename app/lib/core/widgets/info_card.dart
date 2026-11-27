import 'package:material_ui/material_ui.dart';

/// Carte d'information avec icône, titre et texte.
///
/// La couleur d'accent n'est jamais le seul porteur du sens : l'icône et le
/// titre disent la même chose.
class InfoCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Couleur de l'icône ; à défaut, couleur principale du thème.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: accent ?? theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    semanticsLabel: title,
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
