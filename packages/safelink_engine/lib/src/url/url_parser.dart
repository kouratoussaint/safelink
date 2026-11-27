import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/ip_address.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/percent_encoding.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';

/// Lit un lien comme le ferait un navigateur, en suivant le standard URL du
/// WHATWG pour les schémas http et https, et note chaque transformation.
///
/// Le lecteur ne contacte jamais le réseau. Il refuse ce qui n'est pas un
/// lien web plutôt que de deviner.
final class UrlParser {
  /// Crée un lecteur. [maxLength] borne la taille d'un lien, en caractères.
  new({this.maxLength = defaultMaxLength, this._suffixes}) {
    if (maxLength < 1) {
      throw ArgumentError.value(maxLength, 'maxLength', 'doit être positif');
    }
  }

  /// Longueur maximale par défaut d'un lien.
  static const defaultMaxLength = 2048;

  /// Longueur maximale acceptée, en caractères.
  final int maxLength;

  final PublicSuffixList? _suffixes;

  /// Public Suffix List utilisée.
  PublicSuffixList get suffixes => _suffixes ?? PublicSuffixList.embedded;

  /// Schémas courants qui ne désignent pas un site web.
  static const knownNonWebSchemes = {
    'about', 'blob', 'chrome', 'content', 'data', 'file', 'filesystem', //
    'ftp', 'geo', 'intent', 'javascript', 'mailto', 'market', 'sip',
    'sms', 'smsto', 'tel', 'tg', 'ussd', 'viber', 'vbscript', 'whatsapp',
    'ws', 'wss',
  };

  static final _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):');
  static final _tabOrNewline = RegExp('[\t\n\r]');
  static final _digits = RegExp(r'^[0-9]+$');

  /// Caractères ignorés par les navigateurs dans un nom de domaine
  /// (UTS #46) : trait d'union conditionnel, espaces sans chasse, sélecteurs
  /// de variante…
  static final _ignoredInHost = RegExp(
    '[\u00AD\u034F\u180B-\u180F\u200B\u2060\u2064\uFE00-\uFE0F\uFEFF]',
  );

  /// Contrôles de direction du texte, refusés dans un nom de domaine.
  static final _bidiControls = RegExp(
    '[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  /// Lit [input].
  UrlParseResult parse(String input) {
    final steps = <UrlNormalization>{};
    var text = input.trim();
    if (text.isEmpty) return UrlParseFailure(input, UrlParseError.empty);
    if (text.runes.length > maxLength) {
      return UrlParseFailure(input, UrlParseError.tooLong);
    }
    final withoutBreaks = text.replaceAll(_tabOrNewline, '');
    if (withoutBreaks != text) steps.add(UrlNormalization.whitespaceRemoved);
    text = withoutBreaks;

    // Protocole.
    final String scheme;
    var rest = text;
    final schemeMatch = _schemePattern.firstMatch(text);
    if (schemeMatch != null &&
        !_isHostAndPort(schemeMatch[1]!, text.substring(schemeMatch.end))) {
      scheme = schemeMatch[1]!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return UrlParseFailure(
          input,
          UrlParseError.nonWebScheme,
          scheme: scheme,
        );
      }
      rest = text.substring(schemeMatch.end);
    } else {
      scheme = 'https';
      steps.add(UrlNormalization.schemeAdded);
    }
    final explicitScheme = !steps.contains(UrlNormalization.schemeAdded);

    // Barres obliques : un navigateur en accepte un nombre quelconque, et
    // traite « \ » comme « / ».
    var slashes = 0;
    var backslash = false;
    while (slashes < rest.length &&
        (rest[slashes] == '/' || rest[slashes] == r'\')) {
      if (rest[slashes] == r'\') backslash = true;
      slashes++;
    }
    if (explicitScheme && (slashes != 2 || backslash)) {
      steps.add(UrlNormalization.slashesNormalized);
    } else if (!explicitScheme &&
        (backslash || (slashes != 0 && slashes != 2))) {
      return UrlParseFailure(input, UrlParseError.notAUrl);
    }
    rest = rest.substring(slashes);

    // Autorité : identifiants, hôte et port.
    var authorityEnd = rest.length;
    for (final delimiter in const ['/', r'\', '?', '#']) {
      final index = rest.indexOf(delimiter);
      if (index >= 0 && index < authorityEnd) authorityEnd = index;
    }
    final authority = rest.substring(0, authorityEnd);
    var remainder = rest.substring(authorityEnd);

    String? username;
    String? password;
    var hostAndPort = authority;
    final at = authority.lastIndexOf('@');
    if (at >= 0) {
      final userinfo = authority.substring(0, at);
      hostAndPort = authority.substring(at + 1);
      if (!explicitScheme && remainder.isEmpty && !userinfo.contains(':')) {
        return UrlParseFailure(input, UrlParseError.emailAddress);
      }
      final colon = userinfo.indexOf(':');
      final rawUser = colon >= 0 ? userinfo.substring(0, colon) : userinfo;
      final rawPassword = colon >= 0 ? userinfo.substring(colon + 1) : null;
      username = PercentEncoding.encode(rawUser, PercentEncoding.userinfoSet);
      if (rawPassword != null) {
        password = PercentEncoding.encode(
          rawPassword,
          PercentEncoding.userinfoSet,
        );
      }
      if (username != rawUser || password != rawPassword) {
        steps.add(UrlNormalization.percentEncodingAdded);
      }
    }

    String rawHost;
    String? rawPort;
    if (hostAndPort.startsWith('[')) {
      final close = hostAndPort.indexOf(']');
      if (close < 0) return _hostFailure(input, explicitScheme);
      rawHost = hostAndPort.substring(0, close + 1);
      final after = hostAndPort.substring(close + 1);
      if (after.isNotEmpty) {
        if (!after.startsWith(':')) return _hostFailure(input, explicitScheme);
        rawPort = after.substring(1);
      }
    } else {
      final colon = hostAndPort.lastIndexOf(':');
      rawHost = colon >= 0 ? hostAndPort.substring(0, colon) : hostAndPort;
      rawPort = colon >= 0 ? hostAndPort.substring(colon + 1) : null;
    }
    if (rawHost.isEmpty) return _hostFailure(input, explicitScheme);
    if (!explicitScheme && !rawHost.startsWith('[') && !rawHost.contains('.')) {
      return UrlParseFailure(input, UrlParseError.notAUrl);
    }

    int? port;
    if (rawPort != null && rawPort.isNotEmpty) {
      if (!_digits.hasMatch(rawPort)) {
        return UrlParseFailure(input, UrlParseError.invalidPort);
      }
      final significant = rawPort.replaceFirst(RegExp('^0+(?=.)'), '');
      final value = significant.length > 5 ? null : int.parse(significant);
      if (value == null || value > 65535) {
        return UrlParseFailure(input, UrlParseError.invalidPort);
      }
      port = value;
      if (port == (scheme == 'http' ? 80 : 443)) {
        port = null;
        steps.add(UrlNormalization.defaultPortRemoved);
      }
    }

    final host = _parseHost(rawHost, steps);
    if (host == null) return _hostFailure(input, explicitScheme);
    final (asciiHost, hostType) = host;
    PublicSuffixMatch? publicSuffix;
    if (hostType == UrlHostType.domain) {
      publicSuffix = suffixes.lookup(asciiHost);
      if (publicSuffix == null) return _hostFailure(input, explicitScheme);
      if (!explicitScheme && !publicSuffix.isListed) {
        // « fichier.txt » ou « v1.beta » : rien n'indique un site web.
        return UrlParseFailure(input, UrlParseError.notAUrl);
      }
    }

    // Chemin, requête et fragment.
    String? fragment;
    final hash = remainder.indexOf('#');
    if (hash >= 0) {
      fragment = remainder.substring(hash + 1);
      remainder = remainder.substring(0, hash);
    }
    String? query;
    final question = remainder.indexOf('?');
    if (question >= 0) {
      query = remainder.substring(question + 1);
      remainder = remainder.substring(0, question);
    }
    var path = remainder;
    if (path.contains(r'\')) {
      path = path.replaceAll(r'\', '/');
      steps.add(UrlNormalization.slashesNormalized);
    }
    if (path.isEmpty) path = '/';
    final resolved = _resolveDotSegments(path);
    if (resolved != path) steps.add(UrlNormalization.dotSegmentsResolved);

    final encodedPath = PercentEncoding.encode(
      resolved,
      PercentEncoding.pathSet,
    );
    final encodedQuery = query == null
        ? null
        : PercentEncoding.encode(query, PercentEncoding.querySet);
    final encodedFragment = fragment == null
        ? null
        : PercentEncoding.encode(fragment, PercentEncoding.fragmentSet);
    if (encodedPath != resolved ||
        encodedQuery != query ||
        encodedFragment != fragment) {
      steps.add(UrlNormalization.percentEncodingAdded);
    }

    return ParsedUrl(
      input: input,
      scheme: scheme,
      username: username,
      password: password,
      hostType: hostType,
      host: asciiHost,
      port: port,
      path: encodedPath,
      query: encodedQuery,
      fragment: encodedFragment,
      queryParameters: _parseQuery(encodedQuery),
      normalizations: steps,
      publicSuffix: publicSuffix,
    );
  }

  /// « www.example.com:8080 » ou « example.com:443/x » : ce qui précède le
  /// deux-points est un nom de site, pas un protocole.
  static bool _isHostAndPort(String candidate, String afterColon) {
    if (knownNonWebSchemes.contains(candidate.toLowerCase())) return false;
    if (RegExp(r'^([0-9]+([/?#\\]|$)|$)').hasMatch(afterColon)) return true;
    // « com.example.app:/retour » est un schéma d'application ; « site.com:x »
    // est un nom de site suivi d'un port (invalide).
    return candidate.contains('.') && !afterColon.startsWith('/');
  }

  static UrlParseFailure _hostFailure(String input, bool explicitScheme) =>
      UrlParseFailure(
        input,
        explicitScheme ? UrlParseError.invalidHost : UrlParseError.notAUrl,
      );

  /// Hôte en ASCII et sa nature, ou `null` s'il est invalide.
  static (String, UrlHostType)? _parseHost(
    String rawHost,
    Set<UrlNormalization> steps,
  ) {
    if (rawHost.startsWith('[')) {
      if (!rawHost.endsWith(']')) return null;
      final bytes = IpAddress.parseIpv6(
        rawHost.substring(1, rawHost.length - 1),
      );
      if (bytes == null) return null;
      return ('[${IpAddress.formatIpv6(bytes)}]', UrlHostType.ipv6);
    }

    var decoded = rawHost;
    if (rawHost.contains('%')) {
      final strict = PercentEncoding.decodeStrict(rawHost);
      if (strict == null) return null;
      if (strict != rawHost) steps.add(UrlNormalization.hostPercentDecoded);
      decoded = strict;
    }
    if (_bidiControls.hasMatch(decoded)) return null;
    final visible = decoded.replaceAll(_ignoredInHost, '');
    if (visible != decoded) {
      steps.add(UrlNormalization.invisibleCharactersRemoved);
    }

    final normalized = Idna.normalize(visible);
    if (normalized != visible.toLowerCase()) {
      steps.add(UrlNormalization.hostCharactersNormalized);
    }
    if (normalized.runes.any(_isForbiddenHostCodePoint)) return null;
    final ascii = Idna.toAscii(normalized);
    if (ascii == null || !Idna.isValidAce(ascii)) return null;
    if (normalized.endsWith('.')) {
      steps.add(UrlNormalization.trailingDotRemoved);
    }
    if (normalized.runes.any((rune) => rune >= 0x80)) {
      steps.add(UrlNormalization.hostConvertedToPunycode);
    }

    if (IpAddress.endsInNumber(ascii)) {
      final value = IpAddress.parseIpv4(ascii);
      if (value == null) return null;
      final canonical = IpAddress.formatIpv4(value);
      if (canonical != ascii) steps.add(UrlNormalization.ipv4Canonicalized);
      return (canonical, UrlHostType.ipv4);
    }
    return (ascii, UrlHostType.domain);
  }

  /// Caractères interdits dans un nom de domaine par le standard URL.
  static bool _isForbiddenHostCodePoint(int c) =>
      c <= 0x20 ||
      c == 0x7F ||
      c == 0x23 || // #
      c == 0x25 || // %
      c == 0x2F || // /
      c == 0x3A || // :
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x3F || // ?
      c == 0x40 || // @
      c == 0x5B || // [
      c == 0x5C || // \
      c == 0x5D || // ]
      c == 0x5E || // ^
      c == 0x7C; // |

  /// Résout les segments `.` et `..` (y compris encodés `%2e`).
  static String _resolveDotSegments(String path) {
    final segments = path.substring(1).split('/');
    final output = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i].toLowerCase();
      final isLast = i == segments.length - 1;
      if (const {'..', '.%2e', '%2e.', '%2e%2e'}.contains(segment)) {
        if (output.isNotEmpty) output.removeLast();
        if (isLast) output.add('');
      } else if (segment == '.' || segment == '%2e') {
        if (isLast) output.add('');
      } else {
        output.add(segments[i]);
      }
    }
    return '/${output.join('/')}';
  }

  static List<QueryParameter> _parseQuery(String? query) {
    if (query == null || query.isEmpty) return const [];
    return [
      for (final pair in query.split('&'))
        if (pair.isNotEmpty) _parsePair(pair),
    ];
  }

  static QueryParameter _parsePair(String pair) {
    final equals = pair.indexOf('=');
    final name = equals >= 0 ? pair.substring(0, equals) : pair;
    final value = equals >= 0 ? pair.substring(equals + 1) : '';
    return QueryParameter(
      PercentEncoding.decodeLenient(name, plusAsSpace: true),
      PercentEncoding.decodeLenient(value, plusAsSpace: true),
    );
  }
}
