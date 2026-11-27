import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/features/results/pictograms.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Verdict en grand : jauge animée du vert au rouge, pictogramme, mot
/// d'alerte, phrase simple et bouton « Écouter ». Le téléphone vibre en
/// cas de danger.
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

  /// Position de chaque niveau sur la jauge, de gauche (vert) à droite
  /// (rouge) ; `null` : pas d'aiguille.
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
      milliseconds: widget.presentation.level == RiskLevel.danger ? 1600 : 1100,
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Semantics(
            label: l10n.gaugeSemantics(
              VerdictPresentation.levelLabel(l10n, p.level),
            ),
            image: true,
            child: _Gauge(
              animation: _controller,
              level: p.level,
              color: color,
              icon: p.icon,
              colors: [
                colors.success,
                colors.info,
                colors.warning,
                colors.danger,
              ],
              track: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
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
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (sentence.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sentence,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
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
          const SizedBox(height: 16),
          ListenButton(text: widget.speech),
        ],
      ),
    );
  }
}

/// Jauge en demi-cercle et pictogramme du verdict.
class _Gauge extends StatelessWidget {
  const new({
    required this.animation,
    required this.level,
    required this.color,
    required this.icon,
    required this.colors,
    required this.track,
  });

  final Animation<double> animation;
  final RiskLevel level;
  final Color color;
  final IconData icon;
  final List<Color> colors;
  final Color track;

  static const width = 220.0;
  static const height = 132.0;
  static const badge = 68.0;

  @override
  Widget build(BuildContext context) {
    final needle = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    final pop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 0.75, curve: Curves.elasticOut),
    );
    final shake = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.7, 1),
    );
    final index = VerdictHero.gaugeIndex(level);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final dx = level == RiskLevel.danger
              ? math.sin(shake.value * math.pi * 8) * 6 * (1 - shake.value)
              : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GaugePainter(
                    colors: colors,
                    track: track,
                    active: index,
                    needle: needle.value,
                    needleColor: color,
                  ),
                ),
              ),
              Positioned(
                left: (width - badge) / 2 + dx,
                top: height - badge,
                child: Transform.scale(
                  scale: pop.value.clamp(0, 1.4),
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 40, color: onColor),
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

class _GaugePainter extends CustomPainter {
  new({
    required this.colors,
    required this.track,
    required this.active,
    required this.needle,
    required this.needleColor,
  });

  final List<Color> colors;
  final Color track;
  final int? active;
  final double needle;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - _Gauge.badge / 2);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweep = math.pi / 4;
    const gap = 0.06;
    for (var i = 0; i < colors.length; i++) {
      final on = i == active;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = on ? 20 : 13
        ..color = active == null
            ? track.withValues(alpha: 0.3)
            : on
            ? colors[i]
            : colors[i].withValues(alpha: 0.28);
      canvas.drawArc(
        rect,
        math.pi + i * sweep + gap / 2,
        sweep - gap,
        false,
        paint,
      );
    }
    if (active == null) return;
    final target = (active! + 0.5) * sweep;
    final angle = (math.pi + target * needle).clamp(math.pi, 2 * math.pi);
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.needle != needle ||
      old.active != active ||
      old.needleColor != needleColor ||
      old.track != track;
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
