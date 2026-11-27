import 'package:meta/meta.dart';
import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';

/// Transformation appliquée au lien avant l'analyse. Chacune est montrée à
/// l'utilisateur : SafeLink ne corrige jamais un lien en silence.
enum UrlNormalization {
  /// Tabulations ou retours à la ligne retirés à l'intérieur du lien.
  whitespaceRemoved(
    'URL_WHITESPACE_REMOVED',
    'Des retours à la ligne ou tabulations ont été retirés du lien.',
  ),

  /// Protocole absent : `https://` supposé.
  schemeAdded(
    'URL_SCHEME_ADDED',
    'Aucun protocole indiqué : le lien est analysé comme s’il commençait '
        'par https://.',
  ),

  /// Barres obliques inversées ou en nombre inhabituel, interprétées comme
  /// le ferait un navigateur.
  slashesNormalized(
    'URL_SLASHES_NORMALIZED',
    'Les barres obliques du lien sont inhabituelles ; elles ont été '
        'interprétées comme le ferait un navigateur.',
  ),

  /// Nom de domaine écrit avec des codes `%XX`, décodés.
  hostPercentDecoded(
    'URL_HOST_PERCENT_DECODED',
    'Le nom du site était écrit avec des codes %XX ; il a été décodé.',
  ),

  /// Caractères invisibles retirés du nom de domaine, comme le fait un
  /// navigateur.
  invisibleCharactersRemoved(
    'URL_INVISIBLE_CHARS_REMOVED',
    'Des caractères invisibles ont été retirés du nom du site.',
  ),

  /// Caractères du nom ramenés à leur forme usuelle (pleine chasse,
  /// séparateurs Unicode…), hors simple passage en minuscules.
  hostCharactersNormalized(
    'URL_HOST_CHARS_NORMALIZED',
    'Des caractères du nom du site ont été ramenés à leur forme usuelle.',
  ),

  /// Nom international converti en Punycode (`xn--…`).
  hostConvertedToPunycode(
    'URL_HOST_PUNYCODE',
    'Le nom du site contient des caractères non latins ou accentués ; sa '
        'forme technique (xn--…) est aussi analysée.',
  ),

  /// IPv4 écrite sous une forme inhabituelle, ramenée à `a.b.c.d`.
  ipv4Canonicalized(
    'URL_IPV4_CANONICALIZED',
    'L’adresse IP était écrite sous une forme inhabituelle ; elle a été '
        'ramenée à sa forme usuelle.',
  ),

  /// Port par défaut du protocole retiré (80 ou 443).
  defaultPortRemoved(
    'URL_DEFAULT_PORT_REMOVED',
    'Le port indiqué est celui du protocole ; il a été retiré.',
  ),

  /// Point final du nom de domaine retiré.
  trailingDotRemoved(
    'URL_TRAILING_DOT_REMOVED',
    'Le point final du nom du site a été retiré.',
  ),

  /// Segments `.` et `..` du chemin résolus, comme le ferait un navigateur.
  dotSegmentsResolved(
    'URL_DOT_SEGMENTS_RESOLVED',
    'Le chemin contenait des segments « . » ou « .. » ; ils ont été résolus.',
  ),

  /// Espaces ou caractères spéciaux du chemin, de la requête ou des
  /// identifiants encodés en `%XX`.
  percentEncodingAdded(
    'URL_PERCENT_ENCODED',
    'Des espaces ou caractères spéciaux ont été encodés (%XX).',
  );

  new(this.code, this.description);

  /// Code stable.
  final String code;

  /// Explication en français.
  final String description;
}

/// Nature de l'hôte d'un lien.
enum UrlHostType {
  /// Nom de domaine.
  domain,

  /// Adresse IPv4.
  ipv4,

  /// Adresse IPv6.
  ipv6,
}

/// Paramètre de requête décodé (`?nom=valeur`).
@immutable
final class QueryParameter {
  /// Crée un paramètre.
  const new(this.name, this.value);

  /// Nom décodé.
  final String name;

  /// Valeur décodée ; vide si absente.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is QueryParameter && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  /// Nom seul : la valeur peut contenir un jeton ou une donnée personnelle.
  @override
  String toString() => 'QueryParameter($name)';
}

/// Résultat de la lecture d'un lien.
sealed class UrlParseResult {
  const new(this.input);

  /// Texte fourni, tel quel.
  final String input;
}

/// Raison pour laquelle un texte n'est pas un lien analysable.
enum UrlParseError {
  /// Rien à analyser.
  empty('URL_EMPTY', 'Aucun lien à analyser.'),

  /// Lien plus long que la limite réglée.
  tooLong('URL_TOO_LONG', 'Le lien est trop long pour être analysé.'),

  /// Schéma autre que http ou https (`mailto:`, `tel:`, `javascript:`…).
  nonWebScheme(
    'URL_NON_WEB_SCHEME',
    'Ce n’est pas un lien de site web : SafeLink n’analyse que les liens '
        'http et https.',
  ),

  /// Adresse e-mail plutôt que lien.
  emailAddress(
    'URL_EMAIL_ADDRESS',
    'Ce texte ressemble à une adresse e-mail, pas à un lien.',
  ),

  /// Texte qui ne ressemble pas à un lien.
  notAUrl('URL_NOT_A_URL', 'Ce texte ne ressemble pas à un lien.'),

  /// Nom de site ou adresse IP invalide.
  invalidHost(
    'URL_INVALID_HOST',
    'Le nom du site est mal formé ; un navigateur refuserait de l’ouvrir.',
  ),

  /// Port invalide.
  invalidPort('URL_INVALID_PORT', 'Le numéro de port du lien est invalide.');

  new(this.code, this.description);

  /// Code stable.
  final String code;

  /// Explication en français.
  final String description;
}

/// Texte qui n'a pas pu être lu comme un lien http ou https.
final class UrlParseFailure extends UrlParseResult {
  /// Crée un échec.
  const new(super.input, this.error, {this.scheme});

  /// Raison de l'échec.
  final UrlParseError error;

  /// Schéma rencontré, pour [UrlParseError.nonWebScheme] (en minuscules).
  final String? scheme;

  @override
  String toString() => 'UrlParseFailure(${error.code})';
}

/// Lien http ou https décomposé et normalisé comme le ferait un navigateur.
final class ParsedUrl extends UrlParseResult {
  /// Crée un lien décomposé ; utilisé par `UrlParser`.
  new({
    required String input,
    required this.scheme,
    required this.hostType,
    required this.host,
    required this.path,
    required Iterable<UrlNormalization> normalizations,
    required Iterable<QueryParameter> queryParameters,
    this.username,
    this.password,
    this.port,
    this.query,
    this.fragment,
    this.publicSuffix,
  }) : normalizations = Set.unmodifiable(normalizations),
       queryParameters = List.unmodifiable(queryParameters),
       super(input);

  /// `http` ou `https`.
  final String scheme;

  /// Identifiant placé avant `@` (encodé), s'il y en a un.
  final String? username;

  /// Mot de passe placé avant `@` (encodé), s'il y en a un.
  final String? password;

  /// Nature de l'hôte.
  final UrlHostType hostType;

  /// Hôte en ASCII : nom en minuscules et Punycode, IPv4 `a.b.c.d`, IPv6
  /// entre crochets.
  final String host;

  /// Port explicite, s'il diffère du port du protocole.
  final int? port;

  /// Chemin, commençant toujours par `/`.
  final String path;

  /// Requête sans le `?`, s'il y en a une.
  final String? query;

  /// Fragment sans le `#`, s'il y en a un.
  final String? fragment;

  /// Paramètres de la requête, décodés.
  final List<QueryParameter> queryParameters;

  /// Transformations appliquées, dans l'ordre.
  final Set<UrlNormalization> normalizations;

  /// Suffixe public et domaine enregistrable (noms de domaine seulement).
  final PublicSuffixMatch? publicSuffix;

  /// Vrai si le lien indiquait lui-même son protocole.
  bool get hasExplicitScheme =>
      !normalizations.contains(UrlNormalization.schemeAdded);

  /// Vrai si le lien contient un identifiant ou un mot de passe avant `@`.
  bool get hasCredentials => username != null || password != null;

  /// Hôte lisible : labels `xn--` décodés.
  String get hostUnicode =>
      hostType == UrlHostType.domain ? Idna.toUnicode(host) : host;

  /// Vrai si le nom de domaine contient au moins un label international.
  bool get isInternationalized =>
      hostType == UrlHostType.domain &&
      host.split('.').any((label) => label.startsWith(Idna.acePrefix));

  /// Domaine réellement enregistré, par exemple `example.co.uk`.
  String? get registrableDomain => publicSuffix?.registrableDomain;

  /// Port effectif, explicite ou celui du protocole.
  int get effectivePort => port ?? (scheme == 'http' ? 80 : 443);

  /// Lien normalisé complet.
  String get href {
    final buffer = StringBuffer('$scheme://');
    if (hasCredentials) {
      buffer.write(username ?? '');
      if (password != null) buffer.write(':$password');
      buffer.write('@');
    }
    buffer
      ..write(host)
      ..write(port == null ? '' : ':$port')
      ..write(path);
    if (query != null) buffer.write('?$query');
    if (fragment != null) buffer.write('#$fragment');
    return buffer.toString();
  }

  /// Protocole et hôte seulement : le chemin et la requête peuvent contenir
  /// des jetons ou des données personnelles.
  @override
  String toString() => 'ParsedUrl($scheme://$host)';
}
