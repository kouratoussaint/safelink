import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/percent_encoding.dart';

/// Masquage des données sensibles d'un lien avant affichage : jetons de
/// connexion, codes, mots de passe, adresses e-mail, numéros de téléphone.
///
/// Le lien analysé reste intact ; seule sa forme affichée est masquée.
abstract final class UrlMasking {
  /// Texte qui remplace une valeur masquée.
  static const mask = '•••';

  /// Noms de paramètres toujours masqués (comparaison sans casse, `-` lu
  /// comme `_`).
  static const sensitiveNames = {
    'access_token', 'api_key', 'apikey', 'auth', 'authorization', 'bearer', //
    'code', 'email', 'hash', 'id_token', 'jwt', 'key', 'mail', 'msisdn',
    'nonce', 'numero', 'otp', 'pass', 'passwd', 'password', 'phone', 'pin',
    'pwd', 'refresh_token', 'secret', 'session', 'sessionid', 'sid', 'sig',
    'signature', 'tel', 'telephone', 'ticket', 'token',
  };

  /// Fragments de noms qui signalent une donnée sensible.
  static const sensitiveNameParts = [
    'token',
    'pass',
    'secret',
    'session',
    'auth',
    'otp',
    'apikey',
    'api_key',
  ];

  static final _secretLike = RegExp(r'^[A-Za-z0-9_\-.~+/=%]{20,}$');
  static final _letter = RegExp('[A-Za-z]');
  static final _digit = RegExp('[0-9]');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[0-9 .\-]{8,}$');

  /// Vrai si un paramètre nommé [name] contient probablement une donnée
  /// sensible.
  static bool isSensitiveName(String name) {
    final normalized = name.toLowerCase().replaceAll('-', '_');
    return sensitiveNames.contains(normalized) ||
        sensitiveNameParts.any(normalized.contains);
  }

  /// Vrai si [value] ressemble à un secret (longue suite de lettres et de
  /// chiffres), à une adresse e-mail ou à un numéro de téléphone.
  static bool isSensitiveValue(String value) {
    final decoded = PercentEncoding.decodeLenient(value, plusAsSpace: true);
    if (_email.hasMatch(decoded)) return true;
    if (_phone.hasMatch(decoded) &&
        decoded.replaceAll(RegExp('[^0-9]'), '').length >= 8) {
      return true;
    }
    return _secretLike.hasMatch(value) &&
        _letter.hasMatch(value) &&
        _digit.hasMatch(value);
  }

  /// Lien [url] prêt à être affiché, données sensibles masquées. L'hôte est
  /// montré sous sa forme technique (ASCII), qui ne peut pas tromper l'œil.
  static String maskedHref(ParsedUrl url) {
    final buffer = StringBuffer('${url.scheme}://');
    if (url.hasCredentials) {
      final username = url.username ?? '';
      buffer.write(isSensitiveValue(username) ? mask : username);
      if (url.password != null) buffer.write(':$mask');
      buffer.write('@');
    }
    buffer
      ..write(url.host)
      ..write(url.port == null ? '' : ':${url.port}')
      ..write(maskPath(url.path));
    if (url.query != null) buffer.write('?${maskQuery(url.query!)}');
    if (url.fragment != null) {
      buffer.write('#${maskFragment(url.fragment!)}');
    }
    return buffer.toString();
  }

  /// Nombre de valeurs que [maskedHref] masque dans [url].
  /// (le lien normalisé ne contient jamais « • » en clair : ce caractère y
  /// est encodé).
  static int maskedCount(ParsedUrl url) =>
      mask.allMatches(maskedHref(url)).length;

  /// Chemin avec les segments qui ressemblent à des secrets masqués.
  static String maskPath(String path) => path
      .split('/')
      .map((segment) => isSensitiveValue(segment) ? mask : segment)
      .join('/');

  /// Requête avec les valeurs sensibles masquées ; les noms restent
  /// visibles.
  static String maskQuery(String query) => query
      .split('&')
      .map((pair) {
        final equals = pair.indexOf('=');
        if (equals < 0) return isSensitiveValue(pair) ? mask : pair;
        final name = pair.substring(0, equals);
        final value = pair.substring(equals + 1);
        if (value.isEmpty) return pair;
        final decodedName = PercentEncoding.decodeLenient(name);
        return isSensitiveName(decodedName) || isSensitiveValue(value)
            ? '$name=$mask'
            : pair;
      })
      .join('&');

  /// Fragment masqué : traité comme une requête s'il contient des
  /// paramètres (`#access_token=…`), sinon masqué s'il ressemble à un
  /// secret.
  static String maskFragment(String fragment) {
    if (fragment.contains('=')) return maskQuery(fragment);
    return isSensitiveValue(fragment) ? mask : fragment;
  }

  /// [text] tronqué à [maxLength] caractères, avec « … » final s'il a été
  /// coupé.
  static String truncate(String text, int maxLength) {
    final runes = text.runes.toList();
    if (runes.length <= maxLength) return text;
    return '${String.fromCharCodes(runes.take(maxLength - 1))}…';
  }
}
