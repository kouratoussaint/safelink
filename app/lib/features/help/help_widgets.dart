import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/features/results/reason_tiles.dart';

/// Carte de section avec titre annoncé comme en-tête.
class HelpSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ligne : pictogramme dans un disque, puis texte ; [title] en gras
/// au-dessus du texte s'il est donné.
class PictoRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
    this.forbid = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? title;
  final bool forbid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MergeSemantics(
        child: Row(
          children: [
            PictoBadge(icon: icon, color: color, forbid: forbid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  Text(text, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste d'écran dont les blocs apparaissent l'un après l'autre.
class StaggeredList extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      for (final (i, child) in children.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: Appear(index: i, child: child),
        ),
    ],
  );
}
