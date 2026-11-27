import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/ip_address.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/percent_encoding.dart';
import 'package:safelink_engine/src/url/unicode_security.dart';
import 'package:safelink_engine/src/url/url_masking.dart';
import 'package:safelink_engine/src/url/url_parser.dart';

/// Codes stables des indices produits par l'analyse locale des liens.
abstract final class UrlSignalCodes {
  /// Identifiant ressemblant à un nom de site placé avant « @ ».
  static const credentialsDeceptive = 'URL_CREDENTIALS_DECEPTIVE';

  /// Identifiant ou mot de passe placé avant « @ ».
  static const credentials = 'URL_CREDENTIALS';

  /// Nom écrit avec des caractères qui imitent ceux d'une marque.
  static const brandLookalike = 'URL_BRAND_LOOKALIKE';

  /// Nom à une faute de frappe d'une marque.
  static const brandTypo = 'URL_BRAND_TYPO';

  /// Domaine officiel d'une marque recopié au début d'un autre nom.
  static const brandDomainInSubdomain = 'URL_BRAND_DOMAIN_IN_SUBDOMAIN';

  /// Nom de marque dans le nom enregistré par un tiers.
  static const brandInDomain = 'URL_BRAND_IN_DOMAIN';

  /// Nom de marque dans un sous-domaine.
  static const brandInSubdomain = 'URL_BRAND_IN_SUBDOMAIN';

  /// Nom de marque dans le chemin d'un autre site.
  static const brandInPath = 'URL_BRAND_IN_PATH';

  /// Même nom qu'une marque, autre extension.
  static const brandOtherSuffix = 'URL_BRAND_OTHER_SUFFIX';

  /// Mélange d'alphabets dans le nom.
  static const mixedScripts = 'URL_MIXED_SCRIPTS';

  /// Nom entièrement écrit avec des lettres qui imitent l'alphabet latin.
  static const imitatesLatin = 'URL_IMITATES_LATIN';

  /// Adresse IP à la place d'un nom.
  static const ipLiteral = 'URL_IP_LITERAL';

  /// Adresse IP écrite sous une forme inhabituelle.
  static const ipUnusualNotation = 'URL_IP_UNUSUAL_NOTATION';

  /// Nom de site écrit avec des codes %XX.
  static const encodedHost = 'URL_ENCODED_HOST';

  /// Caractères invisibles dans le nom.
  static const invisibleCharacters = 'URL_INVISIBLE_CHARACTERS';

  /// Caractères inhabituels (pleine chasse…) dans le nom.
  static const unusualHostCharacters = 'URL_UNUSUAL_HOST_CHARACTERS';

  /// Mots d'appât dans le nom enregistré (bonus, vérification…).
  static const baitWords = 'URL_BAIT_WORDS';

  /// Paramètre qui renvoie vers un autre site.
  static const redirectParameter = 'URL_REDIRECT_PARAMETER';

  /// Lien vers une application Android à installer.
  static const apkDownload = 'URL_APK_DOWNLOAD';

  /// Raccourcisseur de liens.
  static const shortener = 'URL_SHORTENER';

  /// Port inhabituel.
  static const unusualPort = 'URL_UNUSUAL_PORT';

  /// Nombre élevé de sous-domaines.
  static const manySubdomains = 'URL_MANY_SUBDOMAINS';

  /// Extension absente de la Public Suffix List.
  static const unlistedSuffix = 'URL_UNLISTED_SUFFIX';

  /// Nom sans extension.
  static const singleLabelHost = 'URL_SINGLE_LABEL_HOST';

  /// Barres obliques inhabituelles.
  static const unusualSlashes = 'URL_UNUSUAL_SLASHES';

  /// Connexion non chiffrée.
  static const unencrypted = 'URL_UNENCRYPTED';

  /// Nom international.
  static const internationalized = 'URL_INTERNATIONALIZED';

  /// Site hébergé sur une plateforme ouverte à tous.
  static const sharedHosting = 'URL_SHARED_HOSTING';

  /// Page publiée par un tiers sur un service de partage connu.
  static const userContent = 'URL_USER_CONTENT';

  /// Site signalé par une source de réputation consultée en ligne.
  static const reported = 'URL_REPORTED';

  /// Domaine enregistré très récemment (données d'enregistrement).
  static const domainNew = 'URL_DOMAIN_NEW';

  /// Nom de site inexistant dans le DNS.
  static const domainNotFound = 'URL_DOMAIN_NOT_FOUND';

  /// Tous les codes, dans l'ordre de `docs/URL_RULES.md`.
  static const List<String> all = [
    credentialsDeceptive, brandLookalike, brandTypo, brandDomainInSubdomain,
    credentials, brandInDomain, brandInSubdomain, brandInPath, baitWords, //
    mixedScripts, imitatesLatin, ipLiteral, ipUnusualNotation, encodedHost,
    invisibleCharacters, redirectParameter, apkDownload, brandOtherSuffix,
    unusualHostCharacters, shortener, unusualPort, manySubdomains,
    unlistedSuffix, singleLabelHost, unusualSlashes, internationalized,
    sharedHosting, unencrypted, userContent, reported, domainNew,
    domainNotFound,
  ];

  /// Codes produits par les consultations en ligne.
  static const List<String> online = [reported, domainNew, domainNotFound];
}

/// Règles heuristiques locales appliquées à un lien décomposé.
///
/// Chaque règle produit au plus un indice, avec une gravité, une confiance
/// et une explication en français. Aucune règle ne conclut seule : le
/// verdict combine les indices (voir `UrlVerdictPolicy`).
final class UrlRules {
  /// Crée les règles. [brandMatcher] et [parser] sont injectables pour les
  /// tests.
  new({BrandMatcher? brandMatcher, UrlParser? parser})
    : brandMatcher = brandMatcher ?? BrandMatcher(),
      _parser = parser ?? UrlParser();

  /// Détecteur d'imitations de marques.
  final BrandMatcher brandMatcher;

  final UrlParser _parser;

  /// Raccourcisseurs de liens courants, y compris les liens d'application
  /// qui envoient chaque téléphone vers une destination différente
  /// (`onelink.to`, `onelink.me`, `app.link`) : ils cachent la destination
  /// réelle.
  static const shorteners = {
    'app.link', 'bit.do', 'bit.ly', 'buff.ly', 'cutt.ly', 'goo.gl', 'is.gd', //
    'lnkd.in', 'onelink.me', 'onelink.to', 'ow.ly', 'rb.gy', 'rebrand.ly',
    's.id', 'shorturl.at', 't.co', 't.ly', 'tiny.cc', 'tinyurl.com', 'urlz.fr',
    'v.gd',
  };

  /// Services de partage où n'importe qui publie une page ou un fichier
  /// sous le nom du service : la réputation du nom ne dit rien de la page.
  static const userContentHosts = {
    'docs.google.com', 'drive.google.com', 'sites.google.com', //
    'forms.gle', 'storage.googleapis.com', 'firebasestorage.googleapis.com',
    'forms.office.com', 'onedrive.live.com', '1drv.ms', 'dropbox.com',
    'www.dropbox.com', 'dl.dropboxusercontent.com', 'wetransfer.com',
    'we.tl', 'mega.nz', 'www.mediafire.com', 'mediafire.com', 'ipfs.io',
    'dweb.link', 'linktr.ee', 'telegra.ph', 'notion.site', 'www.notion.so',
    'notion.so', 'canva.site', 'www.canva.com', 'jotform.com',
    'form.jotform.com', 'typeform.com', 'airtable.com',
  };

  /// Mots d'appât fréquents dans les noms de sites frauduleux, en français
  /// et en anglais, sans accents. Le nom enregistré est examiné ; dans les
  /// sous-domaines, un mot isolé comme `login.` est courant chez les sites
  /// légitimes et ne compte pas.
  static const baitWordList = {
    'account', 'alerte', 'assistance', 'bonus', 'cadeau', 'cadeaux', 'claim',
    'colis', 'compte', 'confirm', 'confirmation', 'connexion', 'customs',
    'debloquer', 'deblocage', 'delivery', 'douane', 'free', 'gagnant', //
    'gagner', 'gain', 'gift', 'gratuit', 'gratuite', 'jackpot', 'livraison',
    'login', 'loterie', 'parcel', 'prize', 'promo', 'recompense', 'reward',
    'remboursement', 'secure', 'securise', 'securite', 'security', 'signin',
    'suspendu', 'suspension', 'tirage', 'tracking', 'unlock', 'update',
    'urgent', 'valider', 'validation', 'verification', 'verifier', 'verify',
    'wallet', 'win', 'winner',
  };

  /// Extensions de paquets d'applications Android.
  static const apkExtensions = ['.apk', '.apks', '.xapk'];

  /// Nombre de sous-domaines à partir duquel le nom est jugé inhabituel.
  static const manySubdomainsThreshold = 4;

  /// Indices relevés pour [url], du plus grave au moins grave, et les
  /// rapprochements de marques utilisés.
  (List<RiskSignal>, List<BrandMatch>) evaluate(ParsedUrl url, DateTime now) {
    final signals = <RiskSignal>[];
    void add(
      String code,
      Severity severity,
      Confidence confidence,
      String reason, {
      String? evidence,
    }) {
      signals.add(
        RiskSignal(
          code: code,
          severity: severity,
          confidence: confidence,
          reason: reason,
          source: SignalSource.urlHeuristic,
          detectedAt: now,
          evidence: evidence == null
              ? null
              : UrlMasking.truncate(evidence, RiskSignal.maxEvidenceLength),
        ),
      );
    }

    final brandMatches = brandMatcher.matchUrl(url);
    final isOfficial = brandMatches.any(
      (m) => m.kind == BrandMatchKind.official,
    );

    _credentials(url, add);
    _brands(brandMatches, add);
    if (!isOfficial) _brandInPath(url, add);
    if (!isOfficial) _baitWords(url, add);
    _hostCharacters(url, isOfficial: isOfficial, add);
    _ipAddress(url, add);
    _redirects(url, add);
    _apk(url, add);
    _structure(url, add);

    // Tri stable : du plus grave au moins grave, ordre de détection sinon.
    final ordered = [for (final (i, signal) in signals.indexed) (i, signal)]
      ..sort((a, b) {
        final bySeverity = b.$2.severity.index.compareTo(a.$2.severity.index);
        return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
      });
    return ([for (final (_, signal) in ordered) signal], brandMatches);
  }

  void _credentials(ParsedUrl url, _Add add) {
    if (!url.hasCredentials) return;
    final username = PercentEncoding.decodeLenient(url.username ?? '');
    final looksLikeSite =
        username.contains('.') ||
        brandMatcher.brandsMentionedIn(username).isNotEmpty;
    if (looksLikeSite) {
      final shownUsername = UrlMasking.isSensitiveValue(username)
          ? UrlMasking.mask
          : username;
      add(
        UrlSignalCodes.credentialsDeceptive,
        Severity.high,
        Confidence.high,
        'Le début du lien imite un nom de site, mais le site réellement '
        'ouvert est celui écrit après « @ » : ${url.hostUnicode}.',
        evidence: '$shownUsername@${url.host}',
      );
    } else {
      add(
        UrlSignalCodes.credentials,
        Severity.medium,
        Confidence.medium,
        'Le lien contient un identifiant ou un mot de passe avant « @ ». '
        'Les liens ordinaires n’en contiennent pas.',
        evidence: '${UrlMasking.mask}@${url.host}',
      );
    }
  }

  void _brands(List<BrandMatch> matches, _Add add) {
    final reported = <Brand>{};
    for (final match in matches) {
      if (!reported.add(match.brand)) continue;
      final name = match.brand.name;
      final official = match.brand.domains.first;
      switch (match.kind) {
        case BrandMatchKind.official:
          break;
        case BrandMatchKind.officialDomainInSubdomain:
          add(
            UrlSignalCodes.brandDomainInSubdomain,
            Severity.high,
            Confidence.high,
            'Le lien commence par l’adresse de $name, mais il mène à un '
            'autre site. Le vrai site est désigné par la fin du nom.',
            evidence: match.matched,
          );
        case BrandMatchKind.lookalike:
          add(
            UrlSignalCodes.brandLookalike,
            Severity.high,
            Confidence.high,
            'Le nom du site ressemble à celui de $name ($official), mais il '
            's’écrit avec d’autres caractères.',
            evidence: match.matched,
          );
        case BrandMatchKind.typo:
          add(
            UrlSignalCodes.brandTypo,
            Severity.high,
            Confidence.medium,
            'Le nom du site diffère d’une seule lettre de celui de $name '
            '($official) : une technique courante pour tromper.',
            evidence: match.matched,
          );
        case BrandMatchKind.keywordInDomain:
          add(
            UrlSignalCodes.brandInDomain,
            Severity.medium,
            Confidence.medium,
            'Le nom du site contient « $name » mais ne fait pas partie des '
            'domaines officiels connus de SafeLink pour cette marque.',
            evidence: match.matched,
          );
        case BrandMatchKind.keywordInSubdomain:
          add(
            UrlSignalCodes.brandInSubdomain,
            Severity.medium,
            Confidence.medium,
            '« $name » apparaît au début du nom, mais le site appartient à '
            'un autre domaine.',
            evidence: match.matched,
          );
        case BrandMatchKind.sameNameOtherSuffix:
          add(
            UrlSignalCodes.brandOtherSuffix,
            Severity.low,
            Confidence.low,
            'Le site porte le nom de $name avec une extension qui ne figure '
            'pas parmi ses domaines officiels connus de SafeLink. Il peut '
            's’agir d’un site local légitime ou d’une imitation.',
            evidence: match.matched,
          );
      }
    }
  }

  void _brandInPath(ParsedUrl url, _Add add) {
    final path = PercentEncoding.decodeLenient(url.path);
    final mentioned = brandMatcher.brandsMentionedIn(path);
    if (mentioned.isEmpty) return;
    final names = mentioned.map((b) => b.name).join(', ');
    add(
      UrlSignalCodes.brandInPath,
      Severity.medium,
      Confidence.low,
      'L’adresse cite $names, mais le site n’est pas un domaine officiel '
      'connu de SafeLink pour cette marque.',
      evidence: UrlMasking.maskPath(url.path),
    );
  }

  void _baitWords(ParsedUrl url, _Add add) {
    final label = _registrableLabel(url);
    if (label == null) return;
    // Mots lus tels quels, puis sur le squelette pour ceux écrits avec des
    // caractères trompeurs (le squelette écrit « m » en « rn », d'où les
    // deux lectures).
    final skeleton = Confusables.skeleton(
      Idna.toUnicode(label),
      ignoreMarks: true,
    );
    Set<String> wordsIn(Iterable<String> texts) => {
      for (final text in texts)
        ...text.split(RegExp('[^a-z]+')).where(baitWordList.contains),
    };
    final words = wordsIn([label, skeleton]);
    // Dans les sous-domaines, un mot isolé est courant (`login.`) ; il en
    // faut au moins deux (`login.secure.account.`).
    final registrable = url.registrableDomain!;
    if (url.host.length > registrable.length) {
      final subdomain = url.host.substring(
        0,
        url.host.length - registrable.length - 1,
      );
      final subdomainWords = wordsIn([
        subdomain,
        Confusables.skeleton(Idna.toUnicode(subdomain), ignoreMarks: true),
      ]);
      if (subdomainWords.length >= 2) words.addAll(subdomainWords);
    }
    if (words.isEmpty) return;
    final list = (words.toList()..sort()).join(', ');
    add(
      UrlSignalCodes.baitWords,
      Severity.medium,
      Confidence.low,
      'Le nom du site contient des mots d’appât souvent utilisés par les '
      'arnaques ($list).',
      evidence: Idna.toUnicode(label),
    );
  }

  void _hostCharacters(ParsedUrl url, _Add add, {required bool isOfficial}) {
    final steps = url.normalizations;
    if (steps.contains(UrlNormalization.hostPercentDecoded)) {
      add(
        UrlSignalCodes.encodedHost,
        Severity.medium,
        Confidence.high,
        'Le nom du site est écrit avec des codes %XX, ce qui sert surtout à '
        'le cacher.',
        evidence: url.host,
      );
    }
    if (steps.contains(UrlNormalization.invisibleCharactersRemoved)) {
      add(
        UrlSignalCodes.invisibleCharacters,
        Severity.medium,
        Confidence.high,
        'Le nom du site contient des caractères invisibles.',
        evidence: url.host,
      );
    }
    if (steps.contains(UrlNormalization.hostCharactersNormalized)) {
      add(
        UrlSignalCodes.unusualHostCharacters,
        Severity.low,
        Confidence.medium,
        'Le nom du site est écrit avec des caractères inhabituels (lettres '
        'larges, points spéciaux…).',
        evidence: url.host,
      );
    }
    if (url.hostType != UrlHostType.domain) return;
    if (url.isInternationalized) {
      add(
        UrlSignalCodes.internationalized,
        Severity.info,
        Confidence.high,
        'Le nom du site contient des caractères non latins ou accentués. '
        'Forme technique : ${url.host}.',
        evidence: url.hostUnicode,
      );
    }
    if (isOfficial) return;
    final label = _registrableLabel(url);
    if (label == null) return;
    final unicode = Idna.toUnicode(label);
    if (UnicodeScripts.isMixedScript(unicode)) {
      final scripts = UnicodeScripts.scriptsOf(unicode).toList()..sort();
      add(
        UrlSignalCodes.mixedScripts,
        Severity.medium,
        Confidence.high,
        'Le nom du site mélange plusieurs alphabets (${scripts.join(', ')}) : '
        'certaines lettres peuvent en imiter d’autres.',
        evidence: unicode,
      );
    } else if (Confusables.imitatesAscii(unicode)) {
      add(
        UrlSignalCodes.imitatesLatin,
        Severity.medium,
        Confidence.medium,
        'Le nom du site s’écrit avec des lettres d’un autre alphabet qui '
        'ressemblent à des lettres latines.',
        evidence: unicode,
      );
    }
  }

  void _ipAddress(ParsedUrl url, _Add add) {
    if (url.hostType == UrlHostType.domain) return;
    var reason =
        'Le lien désigne une adresse IP au lieu d’un nom de site. Les '
        'organisations sérieuses utilisent un nom.';
    if (url.hostType == UrlHostType.ipv4) {
      final value = IpAddress.parseIpv4(url.host)!;
      if (IpAddress.isNonPublicIpv4(value)) {
        reason =
            '$reason Cette adresse appartient à un réseau local ou réservé.';
      }
    }
    add(
      UrlSignalCodes.ipLiteral,
      Severity.medium,
      Confidence.high,
      reason,
      evidence: url.host,
    );
    if (url.normalizations.contains(UrlNormalization.ipv4Canonicalized)) {
      add(
        UrlSignalCodes.ipUnusualNotation,
        Severity.medium,
        Confidence.high,
        'L’adresse IP est écrite sous une forme inhabituelle (nombre unique, '
        'octal ou hexadécimal) pour cacher sa vraie valeur : ${url.host}.',
        evidence: url.host,
      );
    }
  }

  void _redirects(ParsedUrl url, _Add add) {
    final ownDomain = url.registrableDomain ?? url.host;
    for (final parameter in url.queryParameters) {
      final target = _redirectTarget(parameter.value);
      if (target == null) continue;
      final targetDomain = target.registrableDomain ?? target.host;
      if (targetDomain == ownDomain) continue;
      add(
        UrlSignalCodes.redirectParameter,
        Severity.medium,
        Confidence.medium,
        'Le lien contient l’adresse d’un autre site '
        '(${target.hostUnicode}) : il peut vous y renvoyer après un '
        'premier passage.',
        evidence: '${parameter.name} → ${target.host}',
      );
      return;
    }
  }

  ParsedUrl? _redirectTarget(String value) {
    for (final candidate in [value, PercentEncoding.decodeLenient(value)]) {
      final lower = candidate.trim().toLowerCase();
      if (!(lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('//') ||
          lower.startsWith('www.'))) {
        continue;
      }
      final result = _parser.parse(candidate.trim());
      if (result is ParsedUrl) return result;
    }
    return null;
  }

  void _apk(ParsedUrl url, _Add add) {
    final path = url.path.toLowerCase();
    if (!apkExtensions.any(path.endsWith)) return;
    add(
      UrlSignalCodes.apkDownload,
      Severity.medium,
      Confidence.high,
      'Le lien télécharge une application Android à installer en dehors du '
      'Play Store. Les fausses applications servent souvent à voler des '
      'codes ou de l’argent.',
      evidence: UrlMasking.maskPath(url.path),
    );
  }

  void _structure(ParsedUrl url, _Add add) {
    final registrable = url.registrableDomain;
    if (userContentHosts.contains(url.host)) {
      add(
        UrlSignalCodes.userContent,
        Severity.info,
        Confidence.high,
        'Le lien mène à ${url.host}, un service où chacun peut publier une '
        'page ou un fichier : le service est connu, mais la page peut être '
        'une imitation.',
        evidence: url.host,
      );
    }
    if (registrable != null && shorteners.contains(registrable)) {
      add(
        UrlSignalCodes.shortener,
        Severity.low,
        Confidence.high,
        'C’est un lien raccourci : il cache le site de destination, que '
        'SafeLink ne peut pas voir sans l’ouvrir.',
        evidence: registrable,
      );
    }
    if (url.port != null) {
      add(
        UrlSignalCodes.unusualPort,
        Severity.low,
        Confidence.medium,
        'Le lien utilise un port inhabituel (${url.port}), rare pour un site '
        'grand public.',
        evidence: ':${url.port}',
      );
    }
    final suffix = url.publicSuffix;
    if (suffix != null && registrable != null) {
      final subdomain = url.host.length > registrable.length
          ? url.host.substring(0, url.host.length - registrable.length - 1)
          : '';
      final count = subdomain.isEmpty ? 0 : subdomain.split('.').length;
      if (count >= manySubdomainsThreshold) {
        add(
          UrlSignalCodes.manySubdomains,
          Severity.low,
          Confidence.medium,
          'Le nom du site comporte $count sous-domaines : un nom très long '
          'peut cacher le vrai site, $registrable.',
          evidence: url.host,
        );
      }
      if (suffix.isPrivateSuffix) {
        add(
          UrlSignalCodes.sharedHosting,
          Severity.info,
          Confidence.high,
          'Le site est hébergé sur ${suffix.publicSuffix}, une plateforme où '
          'chacun peut créer une page.',
          evidence: registrable,
        );
      }
    }
    if (suffix != null && !suffix.isListed) {
      if (registrable == null) {
        add(
          UrlSignalCodes.singleLabelHost,
          Severity.low,
          Confidence.medium,
          'Le nom du site n’a pas d’extension (.bf, .com…) : il ne désigne '
          'pas un site public ordinaire.',
          evidence: url.host,
        );
      } else {
        add(
          UrlSignalCodes.unlistedSuffix,
          Severity.low,
          Confidence.medium,
          'L’extension « .${suffix.publicSuffix} » n’existe pas dans la liste '
          'publique des extensions.',
          evidence: url.host,
        );
      }
    }
    if (url.normalizations.contains(UrlNormalization.slashesNormalized)) {
      add(
        UrlSignalCodes.unusualSlashes,
        Severity.low,
        Confidence.medium,
        'Le lien contient des barres obliques inhabituelles, parfois utilisées '
        'pour tromper.',
      );
    }
    if (url.scheme == 'http') {
      add(
        UrlSignalCodes.unencrypted,
        Severity.info,
        Confidence.high,
        'La connexion ne serait pas chiffrée (http) : ce que vous saisiriez '
        'pourrait être lu en chemin.',
      );
    }
  }

  static String? _registrableLabel(ParsedUrl url) {
    final registrable = url.registrableDomain;
    final suffix = url.publicSuffix;
    if (registrable == null || suffix == null) return null;
    return registrable.substring(
      0,
      registrable.length - suffix.publicSuffix.length - 1,
    );
  }
}

typedef _Add = void Function(
  String code,
  Severity severity,
  Confidence confidence,
  String reason, {
  String? evidence,
});
