import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/pictograms.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Verdict en grand, sur une carte teintée de la couleur du niveau :
/// pictogramme entouré d'un halo, mot d'alerte, phrase simple, barre de
/// niveau en quatre couleurs et bouton « Écouter ». Le téléphone vibre en
/// cas de danger ou d'alerte.
class VerdictHero extends StatefulWidget {
  const new({
    required this.presentation,
    required this.speech,
    this.confidence,
    this.expert = false,
    super.key,
  });

  final VerdictPresentation presentation;

  /// Texte lu par « Écouter ».
  final String speech;

  /// Confiance, affichée en mode expert et toujours lue par TalkBack.
  final Confidence? confidence;

  /// Mode expert : phrase précise au lieu de la phrase simple.
  final bool expert;

  /// Case allumée de la barre de niveau, du vert (0) au rouge (3) ;
  /// `null` : aucune.
  static int? gaugeIndex(RiskLevel level) => switch (level) {
    RiskLevel.nothingObvious => 0,
    RiskLevel.uncertain => 1,
    RiskLevel.attention => 2,
    RiskLevel.danger => 3,
    RiskLevel.notAnalyzable => null,
  };

  @override
  State<VerdictHero> createState() => _VerdictHeroState();
}

class _VerdictHeroState extends State<VerdictHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.presentation.level == RiskLevel.danger ? 1500 : 1100,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.presentation.level) {
        case RiskLevel.danger:
          HapticFeedback.heavyImpact().ignore();
        case RiskLevel.attention:
          HapticFeedback.mediumImpact().ignore();
        case _:
          break;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = SafeLinkColors.of(context);
    final p = widget.presentation;
    final color = VerdictPresentation.colorOf(context, p.level);
    final word = VerdictPresentation.heroWord(l10n, p.level);
    final sentence = widget.expert || p.simple.isEmpty ? p.subtitle : p.simple;
    final confidence = widget.confidence == null
        ? null
        : VerdictPresentation.confidenceLabel(l10n, widget.confidence!);
    final index = VerdictHero.gaugeIndex(p.level);
    return Container(
      decoration: BoxDecoration(
        color: VerdictPresentation.softColorOf(context, p.level),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          ExcludeSemantics(
            child: _HaloBadge(
              animation: _controller,
              level: p.level,
              color: color,
              icon: p.icon,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            header: true,
            label: [
              p.label,
              word,
              sentence,
              ?confidence,
            ].where((s) => s.isNotEmpty).map(spokenSentence).join(' '),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.25, 0.6),
                    ),
                    child: Text(
                      word,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (widget.expert) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  if (sentence.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sentence,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (widget.expert && confidence != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      confidence,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (index != null) ...[
            const SizedBox(height: 14),
            Semantics(
              label: l10n.gaugeSemantics(
                VerdictPresentation.levelLabel(l10n, p.level),
              ),
              image: true,
              child: _LevelBar(
                animation: _controller,
                active: index,
                colors: [
                  colors.success,
                  colors.info,
                  colors.warning,
                  colors.danger,
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ListenButton(
            text: widget.speech,
            background: theme.colorScheme.surface,
            foreground: color,
          ),
        ],
      ),
    );
  }
}

/// Pictogramme du verdict dans un disque plein, entouré de deux halos qui
/// s'ouvrent ; il tremble un instant en cas de danger.
class _HaloBadge extends StatelessWidget {
  const new({
    required this.animation,
    required this.level,
    required this.color,
    required this.icon,
  });

  final Animation<double> animation;
  final RiskLevel level;
  final Color color;
  final IconData icon;

  static const size = 132.0;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    final halo = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    );
    final shake = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.6, 1),
    );
    final onColor = PictoBadge.onColor(color);
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final dx = level == RiskLevel.danger
              ? math.sin(shake.value * math.pi * 8) * 5 * (1 - shake.value)
              : 0.0;
          Widget ring(double diameter, double alpha) => Container(
            width: diameter * (0.7 + 0.3 * halo.value),
            height: diameter * (0.7 + 0.3 * halo.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: alpha * halo.value),
            ),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              ring(size, 0.08),
              ring(100, 0.14),
              Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: pop.value.clamp(0, 1.2),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: onColor, size: 38),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Barre de niveau : quatre cases du vert au rouge, celle du verdict en
/// couleur pleine, les autres pâlies.
class _LevelBar extends StatelessWidget {
  const new({
    required this.animation,
    required this.active,
    required this.colors,
  });

  final Animation<double> animation;
  final int active;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final fill = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
    );
    return SizedBox(
      width: 220,
      height: 8,
      child: AnimatedBuilder(
        animation: fill,
        builder: (context, _) => Row(
          children: [
            for (final (i, color) in colors.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == active
                        ? Color.lerp(
                            color.withValues(alpha: 0.25),
                            color,
                            fill.value,
                          )
                        : color.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Texte lu par « Écouter » : mot d'alerte, phrase simple, indices et
/// gestes, en mots courts.
String verdictSpeech(
  AppLocalizations l10n,
  VerdictPresentation presentation, {
  required List<RiskSignal> signals,
  required List<RecommendedAction> actions,
}) {
  final parts = <String>[
    VerdictPresentation.heroWord(l10n, presentation.level),
    presentation.label,
    if (presentation.simple.isEmpty)
      presentation.subtitle
    else
      presentation.simple,
    for (final s
        in signals.where((s) => s.severity.rank >= Severity.low.rank).take(4))
      signalPictogram(s.code, l10n)?.label ?? s.reason,
    if (actions.isNotEmpty) l10n.listenWhatToDo,
    for (final a in actions)
      actionPictogram(a.code, l10n)?.label ?? a.description,
  ];
  return parts.where((s) => s.trim().isNotEmpty).map(spokenSentence).join(' ');
}
