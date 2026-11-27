import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/codes.dart';
import 'package:safelink_engine/src/common/provider_result.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';

/// Issue d'une consultation en ligne sur un nom de domaine.
enum LookupStatus {
  /// L'information a été trouvée.
  found,

  /// La source a répondu que le nom n'existe pas.
  notFound,

  /// Pas de réponse exploitable (hors ligne, délai dépassé, erreur).
  unavailable,
}

/// Date d'enregistrement d'un domaine, lue dans les données publiques
/// d'enregistrement (RDAP).
@immutable
final class DomainRegistration {
  /// Domaine trouvé, enregistré le [registeredAt].
  new found({required DateTime registeredAt, required DateTime checkedAt})
    : status = LookupStatus.found,
      registeredAt = checkUtc(registeredAt, 'registeredAt'),
      checkedAt = checkUtc(checkedAt, 'checkedAt');

  /// Le registre ne connaît pas ce domaine.
  new notFound({required DateTime checkedAt})
    : status = LookupStatus.notFound,
      registeredAt = null,
      checkedAt = checkUtc(checkedAt, 'checkedAt');

  /// Pas de réponse exploitable.
  new unavailable({required DateTime checkedAt})
    : status = LookupStatus.unavailable,
      registeredAt = null,
      checkedAt = checkUtc(checkedAt, 'checkedAt');

  /// Issue de la consultation.
  final LookupStatus status;

  /// Date d'enregistrement, si elle a été trouvée.
  final DateTime? registeredAt;

  /// Moment de la consultation.
  final DateTime checkedAt;

  /// Âge du domaine au moment de la consultation.
  Duration? get age {
    final registered = registeredAt;
    return registered == null ? null : checkedAt.difference(registered);
  }

  @override
  bool operator ==(Object other) =>
      other is DomainRegistration &&
      other.status == status &&
      other.registeredAt == registeredAt &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(status, registeredAt, checkedAt);
}

/// Existence d'un nom de site dans le DNS, vérifiée auprès d'un résolveur
/// sans filtrage.
@immutable
final class DomainResolution {
  /// Crée le constat.
  new({required this.status, required DateTime checkedAt})
    : checkedAt = checkUtc(checkedAt, 'checkedAt');

  /// [LookupStatus.found] : le nom existe ; [LookupStatus.notFound] : il
  /// n'existe pas (NXDOMAIN).
  final LookupStatus status;

  /// Moment de la consultation.
  final DateTime checkedAt;

  @override
  bool operator ==(Object other) =>
      other is DomainResolution &&
      other.status == status &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(status, checkedAt);
}

/// Ce que l'application a appris en ligne sur un lien, avant l'analyse.
///
/// Le moteur ne fait aucune requête : l'application consulte les sources
/// (après accord de l'utilisateur) et transmet ici leurs réponses.
@immutable
final class OnlineEvidence {
  /// Crée les éléments recueillis.
  const new({this.reputation = const [], this.registration, this.resolution});

  /// Aucune consultation en ligne.
  static const none = OnlineEvidence();

  /// Réponses des sources de réputation.
  final List<ProviderResult> reputation;

  /// Date d'enregistrement du domaine.
  final DomainRegistration? registration;

  /// Existence du nom dans le DNS.
  final DomainResolution? resolution;

  /// Vrai si au moins une consultation a eu lieu.
  bool get isEmpty =>
      reputation.isEmpty && registration == null && resolution == null;
}

/// Noms à consulter en ligne pour un lien.
@immutable
final class OnlineLookupTarget {
  /// Crée la cible.
  const new({required this.host, required this.domain});

  /// Cible d'un lien lu, ou `null` s'il n'y a rien à consulter : adresse
  /// IP, nom sans extension ou sans domaine enregistrable.
  static OnlineLookupTarget? of(ParsedUrl url) {
    final domain = url.registrableDomain;
    if (url.hostType != UrlHostType.domain || domain == null) return null;
    final suffix = url.publicSuffix;
    if (suffix == null || !suffix.isListed) return null;
    return OnlineLookupTarget(host: url.host, domain: domain);
  }

  /// Nom complet du site, en ASCII (`www.exemple.bf`) : seul ce nom est
  /// transmis aux résolveurs, jamais le chemin ni les paramètres.
  final String host;

  /// Domaine enregistré (`exemple.bf`), transmis au registre pour connaître
  /// sa date d'enregistrement.
  final String domain;

  @override
  bool operator ==(Object other) =>
      other is OnlineLookupTarget &&
      other.host == host &&
      other.domain == domain;

  @override
  int get hashCode => Object.hash(host, domain);

  @override
  String toString() => 'OnlineLookupTarget';
}
