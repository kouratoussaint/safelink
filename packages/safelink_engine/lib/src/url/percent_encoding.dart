import 'dart:convert';

/// Encodage « pour cent » (`%20`, `%C3%A9`) des différentes parties d'un
/// lien, avec les ensembles de caractères du standard URL du WHATWG.
abstract final class PercentEncoding {
  /// Décode [input] en octets : chaque `%XX` valide devient un octet, tout
  /// autre caractère est converti en UTF-8. Un `%` isolé est conservé.
  static List<int> decodeToBytes(String input, {bool plusAsSpace = false}) {
    final bytes = <int>[];
    final units = input.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit == 0x25 &&
          i + 2 < units.length &&
          _hexValue(units[i + 1]) >= 0 &&
          _hexValue(units[i + 2]) >= 0) {
        bytes.add(_hexValue(units[i + 1]) * 16 + _hexValue(units[i + 2]));
        i += 2;
      } else if (plusAsSpace && unit == 0x2B) {
        bytes.add(0x20);
      } else if (unit < 0x80) {
        bytes.add(unit);
      } else {
        // Caractère non ASCII, éventuellement en paire de substituts.
        final end = _isHighSurrogate(unit) && i + 1 < units.length
            ? i + 2
            : i + 1;
        bytes.addAll(utf8.encode(input.substring(i, end)));
        i = end - 1;
      }
    }
    return bytes;
  }

  /// Décode [input] ; `null` si les octets obtenus ne forment pas de l'UTF-8
  /// valide.
  static String? decodeStrict(String input) {
    try {
      return utf8.decode(decodeToBytes(input));
    } on FormatException {
      return null;
    }
  }

  /// Décode [input] sans jamais échouer : l'UTF-8 invalide est remplacé par
  /// U+FFFD. Avec [plusAsSpace], `+` devient une espace (paramètres).
  static String decodeLenient(String input, {bool plusAsSpace = false}) =>
      utf8.decode(
        decodeToBytes(input, plusAsSpace: plusAsSpace),
        allowMalformed: true,
      );

  /// Encode en UTF-8 puis `%XX` chaque caractère de [input] pour lequel
  /// [shouldEncode] est vrai. Les `%` déjà présents sont laissés tels quels.
  static String encode(
    String input,
    bool Function(int codePoint) shouldEncode,
  ) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (!shouldEncode(rune)) {
        buffer.writeCharCode(rune);
        continue;
      }
      for (final byte in utf8.encode(String.fromCharCode(rune))) {
        buffer
          ..write('%')
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  /// Ensemble « fragment » : contrôles, espace, `"`, `<`, `>`, `` ` `` et
  /// tout caractère non ASCII.
  static bool fragmentSet(int c) =>
      c <= 0x20 ||
      c >= 0x7F ||
      c == 0x22 ||
      c == 0x3C ||
      c == 0x3E ||
      c == 0x60;

  /// Ensemble « requête » des schémas web : contrôles, espace, `"`, `#`,
  /// `'`, `<`, `>` et tout caractère non ASCII.
  static bool querySet(int c) =>
      c <= 0x20 ||
      c >= 0x7F ||
      c == 0x22 ||
      c == 0x23 ||
      c == 0x27 ||
      c == 0x3C ||
      c == 0x3E;

  /// Ensemble « chemin » : ensemble requête sans `'`, plus `?`, `` ` ``,
  /// `{` et `}`.
  static bool pathSet(int c) =>
      (querySet(c) && c != 0x27) ||
      c == 0x3F ||
      c == 0x60 ||
      c == 0x7B ||
      c == 0x7D;

  /// Ensemble « identifiants » (partie avant `@`) : ensemble chemin plus
  /// `/ : ; = @ [ \ ] ^ |`.
  static bool userinfoSet(int c) =>
      pathSet(c) ||
      c == 0x2F ||
      c == 0x3A ||
      c == 0x3B ||
      c == 0x3D ||
      c == 0x40 ||
      (c >= 0x5B && c <= 0x5E) ||
      c == 0x7C;

  static int _hexValue(int unit) {
    if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
    if (unit >= 0x41 && unit <= 0x46) return unit - 0x41 + 10;
    if (unit >= 0x61 && unit <= 0x66) return unit - 0x61 + 10;
    return -1;
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
