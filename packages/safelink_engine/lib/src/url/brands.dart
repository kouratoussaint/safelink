import 'package:meta/meta.dart';
import 'package:safelink_engine/src/url/brands_data.g.dart';
import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';
import 'package:safelink_engine/src/url/unicode_security.dart';

/// Secteur d'une marque de référence.
enum BrandCategory {
  /// Banque.
  bank('banque'),

  /// Plateforme de cryptomonnaies.
  crypto('plateforme de cryptomonnaies'),

  /// Livraison de colis.
  delivery('livraison de colis'),

  /// Commerce en ligne.
  ecommerce('commerce en ligne'),

  /// Messagerie électronique.
  email('messagerie électronique'),

  /// Vidéo, musique ou télévision.
  media('vidéo, musique ou télévision'),

  /// Messagerie instantanée.
  messaging('messagerie instantanée'),

  /// Transfert d'argent.
  moneyTransfer('transfert d’argent'),

  /// Paiement.
  payment('paiement'),

  /// Institution ou service public.
  publicInstitution('institution ou service public'),

  /// Réseau social.
  social('réseau social'),

  /// Services numériques.
  tech('services numériques'),

  /// Téléphonie et argent mobile.
  telecom('téléphonie et argent mobile');

  new(this.label);

  /// Libellé en français.
  final String label;
}

/// Type de source justifiant un domaine officiel.
enum BrandSourceKind {
  /// Wikidata, propriété « site officiel » (P856).
  wikidata('Wikidata, propriété « site officiel » (P856)'),

  /// BRVM, fiche de la société cotée.
  brvm('BRVM, fiche de la société cotée, rubrique « Site web »');

  new(this.description);

  /// Description en français.
  final String description;
}

/// Source officielle d'un ou plusieurs domaines d'une marque.
@immutable
final class BrandSource {
  /// Crée une source.
  const new({required this.kind, required this.url, required this.domains});

  /// Type de source.
  final BrandSourceKind kind;

  /// Adresse de la source consultée.
  final String url;

  /// Domaines que cette source justifie.
  final List<String> domains;
}

/// Marque souvent imitée, avec ses domaines officiels sourcés.
///
/// Sert uniquement à repérer les imitations : un lien vers un domaine
/// officiel n'est jamais déclaré sûr pour autant.
@immutable
final class Brand {
  /// Crée une marque.
  const new({
    required this.id,
    required this.name,
    required this.category,
    required this.domains,
    required this.keywords,
    required this.tokens,
    required this.sources,
    required this.verifiedOn,
  });

  /// Identifiant stable.
  final String id;

  /// Nom affiché.
  final String name;

  /// Secteur.
  final BrandCategory category;

  /// Domaines enregistrables officiels (ASCII, minuscules).
  final List<String> domains;

  /// Noms recherchés n'importe où dans un nom de domaine (`paypal` dans
  /// `mypaypal-login`).
  final List<String> keywords;

  /// Noms trop courts ou trop courants pour être cherchés à l'intérieur d'un
  /// mot : ils doivent apparaître isolés (`orange` dans `orange-bonus`, pas
  /// dans `orangeraie`).
  final List<String> tokens;

  /// Sources officielles des domaines.
  final List<BrandSource> sources;

  /// Date de vérification des sources (AAAA-MM-JJ).
  final String verifiedOn;

  @override
  bool operator ==(Object other) => other is Brand && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Brand($id)';
}

/// Façon dont un nom de domaine évoque une marque.
///
/// Les valeurs sont rangées de la plus forte à la plus faible.
enum BrandMatchKind {
  /// Domaine officiel de la marque (ce qui ne garantit pas que la page est
  /// sûre).
  official,

  /// Domaine officiel recopié au début d'un autre nom :
  /// `paypal.com.connexion.example`.
  officialDomainInSubdomain,

  /// Nom qui se lit comme celui de la marque mais s'écrit avec d'autres
  /// caractères : `pаypal` (« а » cyrillique), `paypa1`, `rnicrosoft`.
  lookalike,

  /// Nom à une faute de frappe de celui de la marque : `paypall`,
  /// `facebok`.
  typo,

  /// Nom de la marque inclus dans un nom enregistré par un tiers :
  /// `paypal-securite.com`.
  keywordInDomain,

  /// Nom de la marque dans un sous-domaine : `paypal.exemple.com`.
  keywordInSubdomain,

  /// Même nom que la marque, avec une autre extension : `paypal.bf`.
  sameNameOtherSuffix,
}

/// Rapprochement entre un nom de domaine et une marque.
@immutable
final class BrandMatch {
  /// Crée un rapprochement.
  const new(this.brand, this.kind, {required this.matched});

  /// Marque évoquée.
  final Brand brand;

  /// Nature du rapprochement.
  final BrandMatchKind kind;

  /// Partie du nom concernée, en forme lisible (Unicode).
  final String matched;

  @override
  bool operator ==(Object other) =>
      other is BrandMatch &&
      other.brand == brand &&
      other.kind == kind &&
      other.matched == matched;

  @override
  int get hashCode => Object.hash(brand, kind, matched);

  @override
  String toString() => 'BrandMatch(${brand.id}, ${kind.name})';
}

/// Liste des marques de référence et de leurs domaines officiels.
final class BrandRegistry {
  /// Crée une liste ; [suffixes] sert à isoler le nom de chaque domaine.
  new(Iterable<Brand> brands, {PublicSuffixList? suffixes})
    : brands = List.unmodifiable(brands) {
    final psl = suffixes ?? PublicSuffixList.embedded;
    for (final brand in this.brands) {
      for (final domain in brand.domains) {
        _owners[domain] = brand;
        final match = psl.lookup(domain);
        final suffix = match?.publicSuffix ?? domain;
        final label = domain.length > suffix.length
            ? domain.substring(0, domain.length - suffix.length - 1)
            : domain;
        (_labels[brand] ??= {}).add(label);
      }
    }
  }

  /// Liste embarquée (voir `data/brands.json`).
  static final BrandRegistry embedded = BrandRegistry(embeddedBrands);

  /// Marques, dans l'ordre du fichier source.
  final List<Brand> brands;

  final Map<String, Brand> _owners = {};
  final Map<Brand, Set<String>> _labels = {};

  /// Marque dont [registrableDomain] est un domaine officiel.
  Brand? ownerOf(String registrableDomain) => _owners[registrableDomain];

  /// Noms des domaines officiels de [brand], sans extension
  /// (`boaburkinafaso`, `coris-bank`…).
  Set<String> labelsOf(Brand brand) => Set.unmodifiable(_labels[brand] ?? {});

  /// Marque d'identifiant [id].
  Brand? byId(String id) {
    for (final brand in brands) {
      if (brand.id == id) return brand;
    }
    return null;
  }
}

/// Repère les noms de domaine qui imitent une marque de référence.
final class BrandMatcher {
  /// Crée un détecteur.
  new({BrandRegistry? registry})
    : registry = registry ?? BrandRegistry.embedded;

  /// Longueur minimale d'un nom pour chercher une faute de frappe : en
  /// dessous, trop de noms légitimes seraient à une lettre d'une marque.
  static const minTypoLength = 6;

  /// Marques et domaines officiels utilisés.
  final BrandRegistry registry;

  /// Les chiffres séparent aussi les mots : « dhl2024 » contient « dhl ».
  static final _wordSeparators = RegExp('[^a-z]+');

  /// Rapprochements pour le lien [url] ; vide pour une adresse IP ou un nom
  /// sans domaine enregistrable.
  List<BrandMatch> matchUrl(ParsedUrl url) {
    final suffix = url.publicSuffix;
    if (url.hostType != UrlHostType.domain || suffix == null) return const [];
    return matchHost(url.host, suffix);
  }

  /// Rapprochements pour l'hôte [asciiHost] et son suffixe public [suffix].
  ///
  /// Un domaine officiel d'une marque n'est rapproché d'aucune autre.
  List<BrandMatch> matchHost(String asciiHost, PublicSuffixMatch suffix) {
    final registrable = suffix.registrableDomain;
    if (registrable == null) return const [];
    final owner = registry.ownerOf(registrable);
    if (owner != null) {
      return [
        BrandMatch(
          owner,
          BrandMatchKind.official,
          matched: Idna.toUnicode(registrable),
        ),
      ];
    }

    final label = registrable.substring(
      0,
      registrable.length - suffix.publicSuffix.length - 1,
    );
    final labelUnicode = Idna.toUnicode(label);
    final labelSkeleton = Confusables.skeleton(labelUnicode, ignoreMarks: true);
    final labelCompact = labelSkeleton.replaceAll('-', '');
    final labelTokens = _tokens(labelSkeleton);
    final subdomain = asciiHost.length > registrable.length
        ? asciiHost.substring(0, asciiHost.length - registrable.length - 1)
        : '';
    final subdomainUnicode = Idna.toUnicode(subdomain);
    final subdomainSkeleton = Confusables.skeleton(
      subdomainUnicode,
      ignoreMarks: true,
    );
    final subdomainCompact = subdomainSkeleton.replaceAll(RegExp('[-.]'), '');
    final subdomainTokens = _tokens(subdomainSkeleton);

    final rawLower = labelUnicode.toLowerCase();
    final rawCompact = rawLower.replaceAll('-', '');
    final rawTokens = _tokens(rawLower);
    final hasLookalikeCharacters =
        labelSkeleton.replaceAll('-', '') !=
        labelUnicode.toLowerCase().replaceAll('-', '');

    final matches = <BrandMatch>[];
    for (final brand in registry.brands) {
      final forms = _forms(brand);
      BrandMatchKind? best;
      var matched = labelUnicode;
      void consider(BrandMatchKind kind, String part) {
        if (best == null || kind.index < best!.index) {
          best = kind;
          matched = part;
        }
      }

      for (final domain in forms.domains) {
        if ('.$subdomainSkeleton.'.contains('.$domain.')) {
          consider(BrandMatchKind.officialDomainInSubdomain, subdomainUnicode);
        }
      }
      for (final (official, officialSkeleton) in forms.labels) {
        if (label == official) continue;
        if (labelSkeleton == officialSkeleton) {
          consider(BrandMatchKind.lookalike, labelUnicode);
        } else if (_isTypo(
          labelCompact,
          officialSkeleton.replaceAll('-', ''),
          rawLengths: (label.length, official.length),
        )) {
          consider(BrandMatchKind.typo, labelUnicode);
        }
      }
      for (final (keyword, keywordSkeleton) in forms.keywords) {
        if (labelCompact == keywordSkeleton) {
          consider(
            label == keyword
                ? BrandMatchKind.sameNameOtherSuffix
                : hasLookalikeCharacters
                ? BrandMatchKind.lookalike
                : BrandMatchKind.keywordInDomain,
            labelUnicode,
          );
        } else if (labelCompact.contains(keywordSkeleton)) {
          // Le nom de la marque n'apparaît qu'après lecture des caractères
          // trompeurs : il est imité, pas simplement cité.
          consider(
            rawCompact.contains(keyword)
                ? BrandMatchKind.keywordInDomain
                : BrandMatchKind.lookalike,
            labelUnicode,
          );
        } else if (_isTypo(
          labelCompact,
          keywordSkeleton,
          rawLengths: (label.length, keyword.length),
        )) {
          consider(BrandMatchKind.typo, labelUnicode);
        }
        if (subdomainCompact.contains(keywordSkeleton)) {
          consider(BrandMatchKind.keywordInSubdomain, subdomainUnicode);
        }
      }
      for (final (token, tokenSkeleton) in forms.tokens) {
        if (labelTokens.contains(tokenSkeleton)) {
          consider(
            label == token
                ? BrandMatchKind.sameNameOtherSuffix
                : rawTokens.contains(token)
                ? BrandMatchKind.keywordInDomain
                : BrandMatchKind.lookalike,
            labelUnicode,
          );
        }
        if (subdomainTokens.contains(tokenSkeleton)) {
          consider(BrandMatchKind.keywordInSubdomain, subdomainUnicode);
        }
      }
      if (best case final kind?) {
        matches.add(BrandMatch(brand, kind, matched: matched));
      }
    }
    matches.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return matches;
  }

  /// Marques citées dans [text] (chemin d'un lien, texte d'un message) :
  /// mot-clé à l'intérieur d'un mot, ou nom court isolé.
  Set<Brand> brandsMentionedIn(String text) {
    // Minuscules d'abord : « PAYPAL » ou « Gmail » dans un texte comptent.
    final skeleton = Confusables.skeleton(
      text.toLowerCase(),
      ignoreMarks: true,
    );
    final tokens = _tokens(skeleton);
    return {
      for (final brand in registry.brands)
        if (_forms(brand).keywords
                .any((k) => tokens.any((t) => t.contains(k.$2))) ||
            _forms(brand).tokens.any((t) => tokens.contains(t.$2)))
          brand,
    };
  }

  final Map<Brand, _BrandForms> _cache = {};

  _BrandForms _forms(Brand brand) => _cache[brand] ??= _BrandForms(
    domains: [for (final d in brand.domains) Confusables.skeleton(d)],
    labels: [
      for (final l in registry.labelsOf(brand)) (l, Confusables.skeleton(l)),
    ],
    keywords: [for (final k in brand.keywords) (k, Confusables.skeleton(k))],
    tokens: [for (final t in brand.tokens) (t, Confusables.skeleton(t))],
  );

  static Set<String> _tokens(String text) =>
      text.split(_wordSeparators).where((t) => t.isNotEmpty).toSet();

  /// Vrai si [a] et [b] diffèrent d'exactement une insertion, suppression,
  /// substitution ou inversion de deux lettres, et si les noms d'origine
  /// ([rawLengths]) sont assez longs.
  static bool _isTypo(String a, String b, {required (int, int) rawLengths}) {
    if (a == b) return false;
    if (rawLengths.$1 < minTypoLength || rawLengths.$2 < minTypoLength) {
      return false;
    }
    if ((a.length - b.length).abs() > 1) return false;
    return _distanceAtMostOne(a, b);
  }

  static bool _distanceAtMostOne(String a, String b) {
    var i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    final restA = a.substring(i);
    final restB = b.substring(i);
    if (restA.length == restB.length) {
      if (restA.substring(1) == restB.substring(1)) return true;
      return restA.length >= 2 &&
          restA[0] == restB[1] &&
          restA[1] == restB[0] &&
          restA.substring(2) == restB.substring(2);
    }
    return restA.length > restB.length
        ? restA.substring(1) == restB
        : restB.substring(1) == restA;
  }
}

/// Formes d'une marque prêtes à comparer : chaque nom avec son squelette.
final class _BrandForms {
  const new({
    required this.domains,
    required this.labels,
    required this.keywords,
    required this.tokens,
  });

  final List<String> domains;
  final List<(String, String)> labels;
  final List<(String, String)> keywords;
  final List<(String, String)> tokens;
}
