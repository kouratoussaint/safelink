import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/results/pictograms.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Pictogramme dans un disque teinté.
class PictoBadge extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    this.size = 44,
    this.forbid = false,
    super.key,
  });

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
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: size * 0.56),
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
    super.key,
  });

  final Widget badge;
  final String title;

  /// Couleur du cadre.
  final Color color;

  /// Mention au-dessus du titre (gravité, en mode expert).
  final Widget? overline;

  /// Explication complète, montrée une fois déplié.
  final List<Widget> details;

  final bool initiallyOpen;

  /// Vignette : pictogramme au-dessus, mots centrés (grille de gestes).
  final bool vertical;

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
      textAlign: widget.vertical ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final details = AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _open && expandable
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: widget.vertical
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: widget.details,
              ),
            )
          : const SizedBox(width: double.infinity),
    );
    final chevron = ExcludeSemantics(
      child: AnimatedRotation(
        turns: _open ? 0.5 : 0,
        duration: duration,
        child: const Icon(Icons.expand_more),
      ),
    );
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: widget.vertical
          ? Column(
              children: [
                widget.badge,
                const SizedBox(height: 8),
                ?widget.overline,
                title,
                details,
                if (expandable) chevron,
              ],
            )
          : Row(
              children: [
                widget.badge,
                const SizedBox(width: 12),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: expandable,
        expanded: expandable ? _open : null,
        onTapHint: expandable
            ? (_open ? l10n.reasonHide : l10n.reasonShow)
            : null,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: widget.color.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: expandable
              ? InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: content,
                )
              : content,
        ),
      ),
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
    return Column(
      children: [
        for (final signal in shown)
          _ReasonTile(signal: signal, expert: expert, l10n: l10n),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const new({required this.signal, required this.expert, required this.l10n});

  final RiskSignal signal;
  final bool expert;
  final AppLocalizations l10n;

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
              l10n.signalExcerpt('« $evidence »'),
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ),
      ],
    );
  }
}

/// Gestes recommandés, en grandes vignettes ; en mode expert, avec leur
/// phrase complète.
class ActionGrid extends StatelessWidget {
  const new({required this.actions, required this.expert, super.key});

  final List<RecommendedAction> actions;
  final bool expert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = !expert && constraints.maxWidth >= 280 * scale ? 2 : 1;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: Builder(
                  builder: (context) {
                    final picto = actionPictogram(action.code, l10n);
                    final color = picto == null
                        ? theme.colorScheme.primary
                        : picto.forbid
                        ? colors.danger
                        : theme.colorScheme.primary;
                    final grid = columns > 1;
                    return ExplainTile(
                      key: ValueKey('action-${action.code}'),
                      color: color,
                      initiallyOpen: expert,
                      vertical: grid,
                      badge: PictoBadge(
                        icon: picto?.icon ?? Icons.check_circle_outline,
                        color: color,
                        forbid: picto?.forbid ?? false,
                        size: grid ? 60 : 44,
                      ),
                      title: picto?.label ?? action.description,
                      details: [
                        if (picto != null)
                          Text(
                            action.description,
                            textAlign: grid
                                ? TextAlign.center
                                : TextAlign.start,
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
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
