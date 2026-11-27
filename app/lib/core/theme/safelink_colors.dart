import 'package:material_ui/material_ui.dart';

/// Couleurs sémantiques de SafeLink, absentes du `ColorScheme` Material.
///
/// Elles portent un sens (succès, attention, danger) et ne sont jamais
/// utilisées seules : chaque état est aussi signalé par un texte et une
/// icône. Les variantes claires sont assombries pour atteindre un contraste
/// WCAG AA de 4,5:1 (voir docs/UI_UX.md et test/theme/contrast_test.dart).
@immutable
class SafeLinkColors extends ThemeExtension<SafeLinkColors> {
  const new({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.textSecondary,
  });

  /// Jetons du thème clair.
  static const light = SafeLinkColors(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF0369A1),
    textSecondary: Color(0xFF475569),
  );

  /// Jetons du thème sombre.
  static const dark = SafeLinkColors(
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFF87171),
    info: Color(0xFF3BA9FF),
    textSecondary: Color(0xFFA9B8C9),
  );

  /// Aucun indice relevé.
  final Color success;

  /// Indices à examiner.
  final Color warning;

  /// Menace connue ou forts indices.
  final Color danger;

  /// Information neutre.
  final Color info;

  /// Texte secondaire.
  final Color textSecondary;

  /// Récupère les jetons du thème courant.
  static SafeLinkColors of(BuildContext context) =>
      Theme.of(context).extension<SafeLinkColors>()!;

  @override
  SafeLinkColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? textSecondary,
  }) => SafeLinkColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    textSecondary: textSecondary ?? this.textSecondary,
  );

  @override
  SafeLinkColors lerp(SafeLinkColors? other, double t) {
    if (other == null) return this;
    return SafeLinkColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
