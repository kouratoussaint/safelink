import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/features/tips/tip_sheets.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Conseils : fiches de prévention en grandes vignettes, la fiche
/// d'urgence « Déjà piégé ? » en tête. Entièrement locales.
class TipsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sheets = tipSheets(l10n);
    final urgent = sheets.first;
    final others = sheets.skip(1).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(l10n.tipsIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Appear(child: _UrgentTile(sheet: urgent)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final columns = constraints.maxWidth >= 280 * scale ? 2 : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (i, sheet) in others.indexed)
                      SizedBox(
                        width: width,
                        child: Appear(
                          index: i + 1,
                          child: _SheetTile(sheet: sheet),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Vignette d'une fiche : pictogramme et titre.
class _SheetTile extends StatelessWidget {
  const new({required this.sheet});

  final TipSheet sheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = VerdictPresentation.colorOf(context, sheet.level);
    return Semantics(
      button: true,
      onTapHint: AppLocalizations.of(context).tipOpen,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.tip(sheet.id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                PictoBadge(icon: sheet.icon, color: color, size: 60),
                const SizedBox(height: 10),
                Text(
                  sheet.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fiche d'urgence, en large et en rouge.
class _UrgentTile extends StatelessWidget {
  const new({required this.sheet});

  final TipSheet sheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SafeLinkColors.of(context).danger;
    return Semantics(
      button: true,
      onTapHint: AppLocalizations.of(context).tipOpen,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.tip(sheet.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PictoBadge(icon: sheet.icon, color: color, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sheet.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(sheet.trap, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fiche de prévention : le piège, les signes, que faire, et « Écouter ».
class TipDetailScreen extends StatelessWidget {
  const new({required this.id, super.key});

  /// Identifiant de la fiche.
  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sheet = tipSheets(l10n).where((s) => s.id == id).firstOrNull;
    if (sheet == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tipsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.tipNotFound, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.tips),
                  child: Text(l10n.tipBackToTips),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final color = VerdictPresentation.colorOf(context, sheet.level);
    final danger = SafeLinkColors.of(context).danger;
    final children = <Widget>[
      Column(
        children: [
          PictoBadge(icon: sheet.icon, color: color, size: 84),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              sheet.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListenButton(text: sheet.speech(l10n)),
        ],
      ),
      _Block(
        title: l10n.tipTrap,
        color: color,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PictoBadge(icon: Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(sheet.trap, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ],
      ),
      _Block(
        title: sheet.signsTitle ?? l10n.tipSigns,
        color: color,
        children: [for (final line in sheet.signs) _Line(line, color: color)],
      ),
      _Block(
        title: sheet.actionsTitle ?? l10n.tipActions,
        color: theme.colorScheme.primary,
        children: [
          for (final line in sheet.actions)
            _Line(
              line,
              color: line.forbid ? danger : theme.colorScheme.primary,
            ),
        ],
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.shield_outlined),
        label: Text(l10n.tipCheckNow),
        onPressed: () => context.go(AppRoutes.home),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tipsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final (i, child) in children.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                child: Appear(index: i, child: child),
              ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const new({required this.title, required this.color, required this.children});

  final String title;
  final Color color;
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

class _Line extends StatelessWidget {
  const new(this.line, {required this.color});

  final TipLine line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          PictoBadge(icon: line.icon, color: color, forbid: line.forbid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
