import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/results/pictograms.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Pictogramme sur une pastille teintée (ou pleine, ou ronde).
class PictoBadge extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    this.size = 44,
    this.forbid = false,
    this.filled = false,
    this.round = false,
    super.key,
  });

  /// Couleur pleine, pictogramme blanc (ou noir sur une couleur claire).
  final bool filled;

  /// Rond plutôt que carré aux coins arrondis.
  final bool round;

  /// Couleur lisible posée sur [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF081E33);

  final IconData icon;
  final Color color;
  final double size;

  /// Ajoute le signe « interdit » en coin.
  final bool forbid;

  @override
  Widget build(BuildContext context) {
    final danger = SafeLinkColors.of(context).danger;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: filled ? color : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  round ? size / 2 : size * 0.3,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: filled ? onColor(color) : color,
                size: size * 0.5,
              ),
            ),
            if (forbid)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block, color: danger, size: size * 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bloc dépliable : un pictogramme et des mots courts ; un appui montre
/// l'explication complète. En mode expert, il est déplié d'office.
class ExplainTile extends StatefulWidget {
  const new({
    required this.badge,
    required this.title,
    required this.color,
    this.overline,
    this.details = const [],
    this.initiallyOpen = false,
    this.vertical = false,
    this.flat = false,
    super.key,
  });

  final Widget badge;
  final String title;

  /// Couleur du niveau (pastille).
  final Color color;

  /// Mention au-dessus du titre (gravité, en mode expert).
  final Widget? overline;

  /// Explication complète, montrée une fois déplié.
  final List<Widget> details;

  final bool initiallyOpen;

  /// Vignette : pictogramme au-dessus, mots dessous (grille).
  final bool vertical;

  /// Ligne d'une carte groupée : pas de carte propre.
  final bool flat;

  @override
  State<ExplainTile> createState() => _ExplainTileState();
}

class _ExplainTileState extends State<ExplainTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final expandable = widget.details.isNotEmpty;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final title = Text(
      widget.title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.3,
      ),
    );
    final details = AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _open && expandable
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.details,
              ),
            )
          : const SizedBox(width: double.infinity),
    );
    final chevron = ExcludeSemantics(
      child: AnimatedRotation(
        turns: _open ? 0.5 : 0,
        duration: duration,
        child: Icon(
          Icons.expand_more,
          color: SafeLinkColors.of(context).textSecondary,
        ),
      ),
    );
    final content = Padding(
      padding: widget.flat
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
          : const EdgeInsets.all(14),
      child: widget.vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.badge,
                    const Spacer(),
                    if (expandable) chevron,
                  ],
                ),
                const SizedBox(height: 10),
                ?widget.overline,
                title,
                details,
              ],
            )
          : Row(
              children: [
                widget.badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [?widget.overline, title, details],
                  ),
                ),
                if (expandable) chevron,
              ],
            ),
    );
    final toggle = expandable ? () => setState(() => _open = !_open) : null;
    return Semantics(
      button: expandable,
      expanded: expandable ? _open : null,
      onTapHint: expandable
          ? (_open ? l10n.reasonHide : l10n.reasonShow)
          : null,
      child: widget.flat
          ? (toggle == null ? content : InkWell(onTap: toggle, child: content))
          : SoftCard(padding: EdgeInsets.zero, onTap: toggle, child: content),
    );
  }
}

/// Indices relevés, en pictogrammes. Hors du mode expert, les simples
/// informations (adresse remise en forme…) sont omises.
class ReasonList extends StatelessWidget {
  const new({
    required this.signals,
    required this.expert,
    required this.emptyText,
    super.key,
  });

  final List<RiskSignal> signals;
  final bool expert;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = expert
        ? signals
        : signals.where((s) => s.severity.rank >= Severity.low.rank).toList();
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            PictoBadge(
              icon: Icons.check_rounded,
              color: SafeLinkColors.of(context).success,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(emptyText, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }
    return TileGrid(
      columns: expert ? 1 : 2,
      children: [
        for (final signal in shown)
          _ReasonTile(
            signal: signal,
            expert: expert,
            l10n: l10n,
            vertical: !expert,
          ),
      ],
    );
  }
}

/// Vignettes en grille : [columns] par ligne quand la largeur le permet
/// (texte grossi compris), sinon une seule ; les vignettes d'une même
/// ligne ont la même hauteur.
class TileGrid extends StatelessWidget {
  const new({required this.children, this.columns = 2, super.key});

  final List<Widget> children;
  final int columns;

  static const gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final perRow = columns > 1 && constraints.maxWidth >= 280 * scale
            ? columns
            : 1;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += perRow) {
          final cells = children.sublist(
            i,
            (i + perRow).clamp(0, children.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < perRow; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < cells.length ? cells[j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: gap),
              row,
            ],
          ],
        );
      },
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const new({
    required this.signal,
    required this.expert,
    required this.l10n,
    this.vertical = false,
  });

  final RiskSignal signal;
  final bool expert;
  final AppLocalizations l10n;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = VerdictPresentation.levelOfSeverity(signal.severity);
    final color = VerdictPresentation.colorOf(context, level);
    final picto = signalPictogram(signal.code, l10n);
    final evidence = signal.evidence;
    final secondary = SafeLinkColors.of(context).textSecondary;
    return ExplainTile(
      key: ValueKey('reason-${signal.code}-${signal.evidence}'),
      color: color,
      initiallyOpen: expert,
      vertical: vertical,
      badge: PictoBadge(
        icon: picto?.icon ?? VerdictPresentation.iconOf(level),
        color: color,
      ),
      overline: expert
          ? Text(
              VerdictPresentation.severityLabel(l10n, signal.severity),
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            )
          : null,
      title: picto?.label ?? signal.reason,
      details: [
        if (picto != null)
          Text(signal.reason, style: theme.textTheme.bodyMedium),
        if (evidence != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.signalExcerpt('«\u00a0$evidence\u00a0»'),
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ),
      ],
    );
  }
}

/// Gestes recommandés : lignes d'une même carte, pictogramme rond ; le
/// premier geste d'un interdit est en couleur pleine. Un appui montre la
/// phrase complète (dépliée d'office en mode expert).
class ActionGrid extends StatelessWidget {
  const new({required this.actions, required this.expert, super.key});

  final List<RecommendedAction> actions;
  final bool expert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    return GroupedCard(
      children: [
        for (final (i, action) in actions.indexed)
          Builder(
            builder: (context) {
              final picto = actionPictogram(action.code, l10n);
              final forbid = picto?.forbid ?? false;
              final color = forbid ? colors.danger : theme.colorScheme.primary;
              return ExplainTile(
                key: ValueKey('action-${action.code}'),
                color: color,
                initiallyOpen: expert,
                flat: true,
                badge: PictoBadge(
                  icon: picto?.icon ?? Icons.check_circle_outline,
                  color: color,
                  forbid: forbid,
                  filled: forbid && i == 0,
                  round: true,
                  size: 40,
                ),
                title: picto?.label ?? action.description,
                details: [
                  if (picto != null)
                    Text(
                      action.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Explications supplémentaires, repliées hors du mode expert.
class MoreSection extends StatefulWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  State<MoreSection> createState() => _MoreSectionState();
}

class _MoreSectionState extends State<MoreSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          hint: l10n.moreBody,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: duration,
              child: const Icon(Icons.expand_more),
            ),
            label: Text(_open ? l10n.moreHide : l10n.moreShow),
            onPressed: () => setState(() => _open = !_open),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in widget.children) ...[
                      const SizedBox(height: 12),
                      child,
                    ],
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
