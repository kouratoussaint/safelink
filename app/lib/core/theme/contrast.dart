import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Ratio de contraste WCAG 2.x entre deux couleurs opaques, de 1 à 21.
///
/// Utilisé par les tests pour garantir que chaque jeton de texte atteint
/// 4,5:1 et chaque contour d'élément interactif 3:1.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
