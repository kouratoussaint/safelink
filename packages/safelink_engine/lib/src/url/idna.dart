import 'package:safelink_engine/src/url/punycode.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Conversion des noms de domaine entre leur forme Unicode
/// (`bücher.example`) et leur forme ASCII (`xn--bcher-kva.example`).
///
/// Approche volontairement simple et prévisible, suffisante pour l'analyse :
/// séparateurs Unicode ramenés au point, normalisation NFKC, minuscules, puis
/// Punycode label par label. Ce n'est pas une implémentation complète
/// d'UTS #46 ; les écarts éventuels rendent un nom invalide plutôt que de le
/// transformer en un autre.
abstract final class Idna {
  /// Longueur maximale d'un label, en caractères ASCII.
  static const maxLabelLength = 63;

  /// Longueur maximale d'un nom de domaine, en caractères ASCII.
  static const maxDomainLength = 253;

  /// Préfixe des labels encodés en Punycode.
  static const acePrefix = 'xn--';

  static final _separators = RegExp('[。．｡]');

  /// Normalise [domain] : séparateurs Unicode remplacés par « . »,
  /// normalisation NFKC et minuscules.
  static String normalize(String domain) =>
      unorm.nfkc(domain.replaceAll(_separators, '.')).toLowerCase();

  /// Forme ASCII de [domain], ou `null` si le nom est invalide : label vide,
  /// label ou nom trop long, ou caractère impossible à encoder.
  ///
  /// Un point final unique (`example.com.`) est accepté et retiré.
  static String? toAscii(String domain) {
    var normalized = normalize(domain);
    if (normalized.endsWith('.')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.isEmpty) return null;
    final labels = <String>[];
    for (final label in normalized.split('.')) {
      if (label.isEmpty) return null;
      String ascii;
      if (_isAscii(label)) {
        ascii = label;
      } else {
        try {
          ascii = '$acePrefix${Punycode.encode(label)}';
        } on FormatException {
          return null;
        }
      }
      if (ascii.length > maxLabelLength) return null;
      labels.add(ascii);
    }
    final result = labels.join('.');
    return result.length > maxDomainLength ? null : result;
  }

  /// Forme Unicode de [asciiDomain] : chaque label `xn--` est décodé.
  ///
  /// Un label `xn--` invalide est laissé tel quel ; [isValidAce] permet de
  /// le détecter.
  static String toUnicode(String asciiDomain) => asciiDomain
      .toLowerCase()
      .split('.')
      .map((label) => decodeLabel(label) ?? label)
      .join('.');

  /// Décode un label `xn--` (casse ignorée) ; renvoie `null` s'il n'en est
  /// pas un ou s'il est invalide.
  static String? decodeLabel(String label) {
    final lower = label.toLowerCase();
    if (!lower.startsWith(acePrefix)) return null;
    try {
      final decoded = Punycode.decode(lower.substring(acePrefix.length));
      return decoded.isEmpty ? null : decoded;
    } on FormatException {
      return null;
    }
  }

  /// Indique si tous les labels `xn--` de [asciiDomain] se décodent.
  static bool isValidAce(String asciiDomain) => asciiDomain
      .split('.')
      .where((label) => label.toLowerCase().startsWith(acePrefix))
      .every((label) => decodeLabel(label) != null);

  static bool _isAscii(String text) => text.codeUnits.every((u) => u < 0x80);
}
