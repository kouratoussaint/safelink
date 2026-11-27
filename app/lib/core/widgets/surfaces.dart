import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';

/// Carte du style « Clarté » : fond blanc, coins arrondis, ombre très
/// douce, sans contour. Touchable si [onTap] est donné.
class SoftCard extends StatelessWidget {
  const new({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 20,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Fond ; à défaut, la surface du thème.
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeLinkColors.of(context);
    final background = color ?? Theme.of(context).colorScheme.surface;
    final shape = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: color == null ? colors.cardShadow : const [],
      ),
      child: Material(
        color: background,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Bloc titré posé sur le fond de page : titre en Poppins, puis le
/// contenu (vignettes, cartes).
class SectionBlock extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Petit titre gris au-dessus d'un groupe (« Plus rapide », « Aujourd'hui »).
class GroupLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: SafeLinkColors.of(context).textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Lignes d'une même carte, séparées par un trait fin aligné sur le texte.
class GroupedCard extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = SafeLinkColors.of(context).divider;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 70, color: divider),
            child,
          ],
        ],
      ),
    );
  }
}

/// Ligne d'une [GroupedCard] : pastille, titre, précision, et à droite un
/// chevron (si touchable) ou [trailing].
class CardRow extends StatelessWidget {
  const new({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final subtitle = this.subtitle;
    final trailing =
        this.trailing ??
        (onTap == null
            ? null
            : ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: colors.textSecondary),
              ));
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// Barre d'en-tête des onglets (Historique, Conseils, Paramètres) : grand
/// titre à gauche, comme une page.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.title, this.actions = const [], super.key});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: 68,
      titleSpacing: 20,
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 26,
          letterSpacing: -0.3,
        ),
      ),
      actions: [...actions, const SizedBox(width: 8)],
    );
  }
}

/// Grand pictogramme dans un disque plein, entouré d'un halo de sa
/// couleur ; barré d'un signe « interdit » si [forbid].
class HaloIcon extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    this.forbid = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool forbid;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF081E33);
    final colors = SafeLinkColors.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 108,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.10),
              ),
            ),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: onColor, size: 36),
            ),
            if (forbid)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.block, color: colors.danger, size: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
