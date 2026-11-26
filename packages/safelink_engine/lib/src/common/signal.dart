import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/codes.dart';

/// Gravité d'un indice pris isolément.
enum Severity {
  /// Information utile, sans valeur d'alerte à elle seule
  /// (exemple : lien en HTTP).
  info(0),

  /// Indice faible, qui ne compte qu'en combinaison.
  low(1),

  /// Indice moyen.
  medium(2),

  /// Indice fort.
  high(3);

  new(this.rank);

  /// Rang de gravité : plus il est élevé, plus l'indice est grave.
  final int rank;
}

/// Niveau de confiance qualitatif attaché à un indice ou à un verdict.
///
/// Volontairement à trois niveaux : SafeLink n'affiche jamais de
/// pourcentage de sécurité.
enum Confidence {
  /// Confiance faible.
  low,

  /// Confiance moyenne.
  medium,

  /// Confiance élevée.
  high,
}

/// Origine d'un indice.
enum SignalSource {
  /// Règle heuristique locale appliquée à une URL.
  urlHeuristic,

  /// Règle locale appliquée au texte d'un message.
  messageRule,

  /// Correspondance avec une source de réputation.
  threatIntel,
}

/// Indice relevé pendant une analyse, avec son explication.
///
/// Chaque indice conserve une raison lisible, un niveau de confiance et,
/// si utile, un court extrait déjà expurgé des données sensibles.
@immutable
final class RiskSignal {
  /// Crée un indice après validation de ses champs.
  ///
  /// Lève une [ArgumentError] si le code est mal formé, si la raison est
  /// vide, si l'extrait dépasse [maxEvidenceLength] caractères ou si la date
  /// n'est pas en UTC.
  new({
    required String code,
    required this.severity,
    required this.confidence,
    required String reason,
    required this.source,
    required DateTime detectedAt,
    String? evidence,
  }) : code = checkStableCode(code, 'code'),
       reason = checkNotBlank(reason, 'reason'),
       detectedAt = checkUtc(detectedAt, 'detectedAt'),
       evidence = _checkEvidence(evidence);

  /// Longueur maximale d'un extrait cité dans un résultat.
  static const int maxEvidenceLength = 120;

  /// Code stable de l'indice, par exemple `USERINFO_PRESENT`.
  final String code;

  /// Gravité de l'indice pris isolément.
  final Severity severity;

  /// Confiance accordée à l'indice.
  final Confidence confidence;

  /// Explication en français simple, affichée à l'utilisateur.
  final String reason;

  /// Origine de l'indice.
  final SignalSource source;

  /// Moment de la détection, en UTC.
  final DateTime detectedAt;

  /// Court extrait justifiant l'indice, déjà expurgé ; absent si inutile.
  final String? evidence;

  static String? _checkEvidence(String? evidence) {
    if (evidence == null) return null;
    if (evidence.trim().isEmpty) {
      throw ArgumentError.value(
        evidence,
        'evidence',
        "L'extrait ne peut pas être vide ; utiliser null.",
      );
    }
    if (evidence.length > maxEvidenceLength) {
      throw ArgumentError.value(
        evidence,
        'evidence',
        "L'extrait dépasse $maxEvidenceLength caractères.",
      );
    }
    return evidence;
  }

  @override
  bool operator ==(Object other) =>
      other is RiskSignal &&
      other.code == code &&
      other.severity == severity &&
      other.confidence == confidence &&
      other.reason == reason &&
      other.source == source &&
      other.detectedAt == detectedAt &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(
    code,
    severity,
    confidence,
    reason,
    source,
    detectedAt,
    evidence,
  );

  @override
  String toString() => 'RiskSignal($code, ${severity.name}, ${source.name})';
}
