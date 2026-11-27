import 'package:meta/meta.dart';
import 'package:safelink_engine/src/url/psl_data.g.dart';

/// Résultat d'une recherche dans la Public Suffix List.
@immutable
final class PublicSuffixMatch {
  /// Crée un résultat.
  const new({
    required this.publicSuffix,
    required this.registrableDomain,
    required this.isPrivateSuffix,
    required this.isListed,
  });

  /// Suffixe public, par exemple `com`, `co.uk` ou `blogspot.com`.
  final String publicSuffix;

  /// Domaine enregistrable (suffixe public + un label), par exemple
  /// `example.co.uk` ; `null` si le nom est lui-même un suffixe public.
  final String? registrableDomain;

  /// Vrai si la règle appliquée vient de la section privée de la liste
  /// (hébergeurs et plateformes où chacun peut créer un sous-domaine).
  final bool isPrivateSuffix;

  /// Faux si aucune règle ne correspond et que la règle par défaut `*` a été
  /// appliquée (extension inconnue de la liste).
  final bool isListed;

  @override
  bool operator ==(Object other) =>
      other is PublicSuffixMatch &&
      other.publicSuffix == publicSuffix &&
      other.registrableDomain == registrableDomain &&
      other.isPrivateSuffix == isPrivateSuffix &&
      other.isListed == isListed;

  @override
  int get hashCode =>
      Object.hash(publicSuffix, registrableDomain, isPrivateSuffix, isListed);

  @override
  String toString() =>
      'PublicSuffixMatch($publicSuffix, ${registrableDomain ?? '-'})';
}

/// Public Suffix List : détermine le domaine réellement enregistré d'un nom
/// d'hôte, sans se contenter des « deux dernières parties ».
///
/// Algorithme de https://publicsuffix.org/list/ : règle d'exception
/// prioritaire, sinon règle la plus longue, sinon règle par défaut `*`.
/// Les deux sections (ICANN et privée) sont utilisées : un site hébergé sur
/// `exemple.blogspot.com` est ainsi distinct de `blogspot.com`.
final class PublicSuffixList {
  /// Construit une liste à partir de règles en ASCII, une par ligne.
  new fromRules({
    required String icannRules,
    required String privateRules,
    this.retrievedOn = 'inconnue',
  }) {
    _load(icannRules, isPrivate: false);
    _load(privateRules, isPrivate: true);
  }

  /// Liste embarquée dans le moteur (voir `tools/update_psl.py`).
  static final PublicSuffixList embedded = PublicSuffixList.fromRules(
    icannRules: pslIcannRules,
    privateRules: pslPrivateRules,
    retrievedOn: pslRetrievedOn,
  );

  /// Date de téléchargement de la liste.
  final String retrievedOn;

  // Pour chaque table : règle → vrai si elle vient de la section privée.
  final Map<String, bool> _normal = {};
  final Map<String, bool> _wildcard = {};
  final Map<String, bool> _exception = {};

  /// Nombre de règles chargées.
  int get length => _normal.length + _wildcard.length + _exception.length;

  void _load(String text, {required bool isPrivate}) {
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('!')) {
        _exception[line.substring(1)] = isPrivate;
      } else if (line.startsWith('*.')) {
        _wildcard[line.substring(2)] = isPrivate;
      } else {
        _normal[line] = isPrivate;
      }
    }
  }

  /// Recherche [asciiHost] (minuscules, labels Unicode déjà en Punycode).
  ///
  /// Renvoie `null` si le nom est vide ou contient un label vide.
  PublicSuffixMatch? lookup(String asciiHost) {
    if (asciiHost.isEmpty) return null;
    final labels = asciiHost.split('.');
    if (labels.any((label) => label.isEmpty)) return null;

    // Règle par défaut « * » : le dernier label seul.
    var suffixLength = 1;
    var isPrivate = false;
    var isListed = false;
    for (var n = 1; n <= labels.length; n++) {
      final candidate = labels.sublist(labels.length - n).join('.');
      final exception = _exception[candidate];
      if (exception != null) {
        // Une règle d'exception l'emporte sur toutes les autres : le suffixe
        // public est alors son parent.
        suffixLength = n - 1;
        isPrivate = exception;
        isListed = true;
        break;
      }
      final normal = _normal[candidate];
      if (normal != null) {
        suffixLength = n;
        isPrivate = normal;
        isListed = true;
      }
      if (n >= 2) {
        // Joker « *.parent » : tout label sous `parent` est un suffixe.
        final parent = labels.sublist(labels.length - n + 1).join('.');
        final wildcard = _wildcard[parent];
        if (wildcard != null) {
          suffixLength = n;
          isPrivate = wildcard;
          isListed = true;
        }
      }
    }

    final publicSuffix = labels.sublist(labels.length - suffixLength).join('.');
    final registrable = labels.length > suffixLength
        ? labels.sublist(labels.length - suffixLength - 1).join('.')
        : null;
    return PublicSuffixMatch(
      publicSuffix: publicSuffix,
      registrableDomain: registrable,
      isPrivateSuffix: isPrivate,
      isListed: isListed,
    );
  }
}
