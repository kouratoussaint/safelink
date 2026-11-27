import 'package:flutter/painting.dart';

/// Couleurs de la charte SafeLink (cahier des charges, §4).
///
/// Ces valeurs d'origine ne sont pas toutes lisibles en texte sur fond
/// clair : l'interface passe par les jetons de `AppTheme` et de
/// `SafeLinkColors`, dont les contrastes sont vérifiés par les tests.
abstract final class BrandPalette {
  /// Bleu nuit, fond principal.
  static const navy = Color(0xFF081E33);

  /// Turquoise, actions principales.
  static const turquoise = Color(0xFF00C2A8);

  /// Bleu d'accent.
  static const accentBlue = Color(0xFF3BA9FF);

  /// Vert de résultat.
  static const green = Color(0xFF22C55E);

  /// Ambre d'attention.
  static const amber = Color(0xFFF59E0B);

  /// Rouge de danger.
  static const red = Color(0xFFEF4444);

  /// Blanc.
  static const white = Color(0xFFFFFFFF);
}
