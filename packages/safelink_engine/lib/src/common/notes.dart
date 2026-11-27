import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/codes.dart';

/// Limite d'une analyse : ce qui n'a pas été vérifié ou ne peut pas l'être.
///
/// Chaque résultat en affiche au moins une (cahier des charges, KPI).
@immutable
final class Limitation {
  /// Crée une limite. Lève une [ArgumentError] si le code est mal formé ou
  /// si la description est vide.
  new({required String code, required String description})
    : code = checkStableCode(code, 'code'),
      description = checkNotBlank(description, 'description');

  /// Code stable, par exemple `REPUTATION_NOT_CHECKED`.
  final String code;

  /// Explication en français simple.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is Limitation &&
      other.code == code &&
      other.description == description;

  @override
  int get hashCode => Object.hash(code, description);

  @override
  String toString() => 'Limitation($code)';
}

/// Geste recommandé à l'utilisateur, adapté au résultat.
@immutable
final class RecommendedAction {
  /// Crée un geste recommandé. Lève une [ArgumentError] si le code est mal
  /// formé ou si la description est vide.
  new({required String code, required String description})
    : code = checkStableCode(code, 'code'),
      description = checkNotBlank(description, 'description');

  /// Code stable, par exemple `NEVER_SHARE_CODES`.
  final String code;

  /// Conseil en français simple.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is RecommendedAction &&
      other.code == code &&
      other.description == description;

  @override
  int get hashCode => Object.hash(code, description);

  @override
  String toString() => 'RecommendedAction($code)';
}
