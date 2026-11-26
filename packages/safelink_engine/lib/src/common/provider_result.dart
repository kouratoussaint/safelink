import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/codes.dart';

/// Issue d'une consultation de source de réputation.
enum ProviderStatus {
  /// L'adresse figure dans une liste valide.
  match,

  /// L'adresse ne figure pas dans une liste valide et récente. Cela ne
  /// prouve pas qu'elle est sûre.
  noMatch,

  /// Aucune source n'est disponible (non autorisée, non téléchargée, ou
  /// refus de l'utilisateur).
  unavailable,

  /// La liste locale est trop ancienne pour conclure.
  stale,

  /// La consultation a échoué (fichier corrompu, délai dépassé, quota…).
  error,
}

/// Catégorie de menace signalée par une source.
enum ThreatType {
  /// Hameçonnage.
  phishing,

  /// Distribution de logiciel malveillant.
  malware,

  /// Autre catégorie déclarée par la source.
  other,
}

/// Entrée correspondante dans une source de réputation.
@immutable
final class ThreatMatch {
  /// Crée une correspondance. Lève une [ArgumentError] si [reportedAt]
  /// n'est pas en UTC.
  new({required this.threatType, DateTime? reportedAt, this.reference})
    : reportedAt = reportedAt == null
          ? null
          : checkUtc(reportedAt, 'reportedAt');

  /// Catégorie de menace.
  final ThreatType threatType;

  /// Date du signalement d'origine, si la source la fournit.
  final DateTime? reportedAt;

  /// Référence publique de l'entrée dans la source, si elle existe.
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is ThreatMatch &&
      other.threatType == threatType &&
      other.reportedAt == reportedAt &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(threatType, reportedAt, reference);
}

/// Résultat d'une source de réputation pour une adresse donnée.
///
/// Conserve la provenance, la date de vérification et l'âge de la liste,
/// afin que l'interface puisse toujours dire ce qui a été vérifié et quand.
@immutable
final class ProviderResult {
  /// Crée un résultat après validation des invariants :
  /// - `match` exige au moins une correspondance, les autres statuts aucune ;
  /// - `errorCode` est exigé pour `error` et interdit sinon ;
  /// - les dates sont en UTC et la liste n'est pas datée du futur.
  new({
    required String providerId,
    required this.status,
    required DateTime checkedAt,
    List<ThreatMatch> matches = const [],
    DateTime? feedUpdatedAt,
    this.feedVersion,
    String? errorCode,
  }) : providerId = checkStableCode(providerId, 'providerId'),
       checkedAt = checkUtc(checkedAt, 'checkedAt'),
       matches = List.unmodifiable(matches),
       feedUpdatedAt = feedUpdatedAt == null
           ? null
           : checkUtc(feedUpdatedAt, 'feedUpdatedAt'),
       errorCode = errorCode == null
           ? null
           : checkStableCode(errorCode, 'errorCode') {
    if ((status == ProviderStatus.match) != this.matches.isNotEmpty) {
      throw ArgumentError(
        'Le statut « match » exige au moins une correspondance, '
        'et les autres statuts aucune.',
      );
    }
    if ((status == ProviderStatus.error) != (this.errorCode != null)) {
      throw ArgumentError(
        'Un code d’erreur est requis pour le statut « error » '
        'et interdit pour les autres.',
      );
    }
    final updated = this.feedUpdatedAt;
    if (updated != null && updated.isAfter(this.checkedAt)) {
      throw ArgumentError.value(
        feedUpdatedAt,
        'feedUpdatedAt',
        'La liste ne peut pas être plus récente que la vérification.',
      );
    }
  }

  /// Identifiant stable de la source, par exemple `PHISHTANK`.
  final String providerId;

  /// Issue de la consultation.
  final ProviderStatus status;

  /// Moment de la consultation, en UTC.
  final DateTime checkedAt;

  /// Correspondances trouvées (vide sauf pour [ProviderStatus.match]).
  final List<ThreatMatch> matches;

  /// Date de mise à jour de la liste utilisée, si connue.
  final DateTime? feedUpdatedAt;

  /// Version de la liste utilisée, si la source en publie une.
  final String? feedVersion;

  /// Code d'erreur stable, présent uniquement pour [ProviderStatus.error].
  final String? errorCode;

  /// Âge de la liste au moment de la consultation, si sa date est connue.
  Duration? get feedAge {
    final updated = feedUpdatedAt;
    return updated == null ? null : checkedAt.difference(updated);
  }

  /// Indique si la liste avait au plus [maxAge] lors de la consultation.
  ///
  /// Une liste sans date n'est jamais considérée comme récente.
  bool isFreshWithin(Duration maxAge) {
    final age = feedAge;
    return age != null && age <= maxAge;
  }

  /// Indique si la consultation a réellement permis de conclure
  /// (correspondance ou absence de correspondance).
  bool get isConclusive =>
      status == ProviderStatus.match || status == ProviderStatus.noMatch;

  @override
  bool operator ==(Object other) =>
      other is ProviderResult &&
      other.providerId == providerId &&
      other.status == status &&
      other.checkedAt == checkedAt &&
      _listEquals(other.matches, matches) &&
      other.feedUpdatedAt == feedUpdatedAt &&
      other.feedVersion == feedVersion &&
      other.errorCode == errorCode;

  @override
  int get hashCode => Object.hash(
    providerId,
    status,
    checkedAt,
    Object.hashAll(matches),
    feedUpdatedAt,
    feedVersion,
    errorCode,
  );

  @override
  String toString() => 'ProviderResult($providerId, ${status.name})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
