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
    required this.canvas,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.infoSoft,
    required this.neutralSoft,
    required this.divider,
    required this.cardShadow,
  });

  /// Jetons du thème clair.
  static const light = SafeLinkColors(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF0369A1),
    textSecondary: Color(0xFF4A5A6B),
    canvas: Color(0xFFF5F7FA),
    successSoft: Color(0xFFEBF6EE),
    warningSoft: Color(0xFFFFF1E0),
    dangerSoft: Color(0xFFFDEDED),
    infoSoft: Color(0xFFEAF2FB),
    neutralSoft: Color(0xFFEEF2F5),
    divider: Color(0xFFEEF2F5),
    cardShadow: [
      BoxShadow(color: Color(0x0F081E33), blurRadius: 12, offset: Offset(0, 2)),
    ],
  );

  /// Jetons du thème sombre.
  static const dark = SafeLinkColors(
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFF87171),
    info: Color(0xFF3BA9FF),
    textSecondary: Color(0xFFA9B8C9),
    canvas: Color(0xFF06182A),
    successSoft: Color(0xFF0E3322),
    warningSoft: Color(0xFF3A2708),
    dangerSoft: Color(0xFF3D1414),
    infoSoft: Color(0xFF0E2E4C),
    neutralSoft: Color(0xFF13314F),
    divider: Color(0xFF1A3856),
    cardShadow: [],
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

  /// Fond des pages, sur lequel se posent les cartes.
  final Color canvas;

  /// Fonds teintés associés aux couleurs sémantiques (pastilles, verdict).
  final Color successSoft;

  /// Fond teinté « attention ».
  final Color warningSoft;

  /// Fond teinté « danger ».
  final Color dangerSoft;

  /// Fond teinté « information ».
  final Color infoSoft;

  /// Fond teinté neutre (champs, pistes, pastilles grises).
  final Color neutralSoft;

  /// Séparateurs entre lignes d'une carte.
  final Color divider;

  /// Ombre douce des cartes (aucune en thème sombre).
  final List<BoxShadow> cardShadow;

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
    Color? canvas,
    Color? successSoft,
    Color? warningSoft,
    Color? dangerSoft,
    Color? infoSoft,
    Color? neutralSoft,
    Color? divider,
    List<BoxShadow>? cardShadow,
  }) => SafeLinkColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    textSecondary: textSecondary ?? this.textSecondary,
    canvas: canvas ?? this.canvas,
    successSoft: successSoft ?? this.successSoft,
    warningSoft: warningSoft ?? this.warningSoft,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    infoSoft: infoSoft ?? this.infoSoft,
    neutralSoft: neutralSoft ?? this.neutralSoft,
    divider: divider ?? this.divider,
    cardShadow: cardShadow ?? this.cardShadow,
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
      canvas: Color.lerp(canvas, other.canvas, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      neutralSoft: Color.lerp(neutralSoft, other.neutralSoft, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}
