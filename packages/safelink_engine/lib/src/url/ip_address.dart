/// Adresses IP littérales dans un lien, selon le standard URL du WHATWG
/// (celui que suivent les navigateurs).
///
/// Un navigateur accepte des formes trompeuses d'IPv4 : `3232235777`,
/// `0xC0.0xA8.1.1`, `0300.0250.1.1` ou `192.168.257` désignent toutes
/// `192.168.1.1`. SafeLink les ramène à la forme usuelle pour les montrer.
abstract final class IpAddress {
  /// Valeur au-delà de laquelle un nombre est forcément invalide ; évite les
  /// calculs sur des entiers démesurés.
  static final BigInt _tooLarge = BigInt.from(1) << 40;

  /// Test « le nom se termine par un nombre » du standard URL : si vrai, le
  /// nom doit être une IPv4 valide, sinon le lien est invalide.
  static bool endsInNumber(String asciiHost) {
    final parts = asciiHost.split('.');
    if (parts.last.isEmpty) {
      if (parts.length == 1) return false;
      parts.removeLast();
    }
    final last = parts.last;
    if (last.isNotEmpty && last.codeUnits.every(_isDecimalDigit)) return true;
    return _parseNumber(last) != null;
  }

  /// Valeur 32 bits de l'IPv4 [asciiHost], ou `null` si elle est invalide.
  static int? parseIpv4(String asciiHost) {
    final parts = asciiHost.split('.');
    if (parts.length > 1 && parts.last.isEmpty) parts.removeLast();
    if (parts.length > 4) return null;
    final numbers = <BigInt>[];
    for (final part in parts) {
      final number = _parseNumber(part);
      if (number == null) return null;
      numbers.add(number);
    }
    final byteLimit = BigInt.from(255);
    for (final number in numbers.take(numbers.length - 1)) {
      if (number > byteLimit) return null;
    }
    final last = numbers.last;
    if (last >= BigInt.from(256).pow(5 - numbers.length)) return null;
    var value = last.toInt();
    for (var i = 0; i < numbers.length - 1; i++) {
      value += numbers[i].toInt() << (8 * (3 - i));
    }
    return value;
  }

  /// Forme usuelle `a.b.c.d` d'une IPv4.
  static String formatIpv4(int value) =>
      [for (var shift = 24; shift >= 0; shift -= 8) (value >> shift) & 0xFF]
          .join('.');

  /// Indique si l'IPv4 est privée, locale ou réservée (RFC 1918, 6598,
  /// boucle locale, lien local, 0.0.0.0/8, multidiffusion et au-delà).
  static bool isNonPublicIpv4(int value) {
    final a = (value >> 24) & 0xFF;
    final b = (value >> 16) & 0xFF;
    return a == 0 ||
        a == 10 ||
        a == 127 ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        a >= 224;
  }

  /// Octets de l'IPv6 [address] (sans crochets), ou `null` si invalide.
  static List<int>? parseIpv6(String address) {
    try {
      return Uri.parseIPv6Address(address);
    } on FormatException {
      return null;
    }
  }

  /// Forme compressée d'une IPv6 (16 octets), comme la sérialise un
  /// navigateur : minuscules, zéros de tête retirés, plus longue suite de
  /// groupes nuls remplacée par `::`.
  static String formatIpv6(List<int> bytes) {
    final pieces = [
      for (var i = 0; i < 16; i += 2) (bytes[i] << 8) | bytes[i + 1],
    ];
    var compress = -1;
    var bestLength = 1;
    for (var i = 0; i < 8;) {
      if (pieces[i] != 0) {
        i++;
        continue;
      }
      var j = i;
      while (j < 8 && pieces[j] == 0) {
        j++;
      }
      if (j - i > bestLength) {
        compress = i;
        bestLength = j - i;
      }
      i = j;
    }
    final buffer = StringBuffer();
    var ignoreZero = false;
    for (var i = 0; i < 8; i++) {
      if (ignoreZero && pieces[i] == 0) continue;
      ignoreZero = false;
      if (i == compress) {
        buffer.write(i == 0 ? '::' : ':');
        ignoreZero = true;
        continue;
      }
      buffer.write(pieces[i].toRadixString(16));
      if (i != 7) buffer.write(':');
    }
    return buffer.toString();
  }

  /// Nombre d'une partie d'IPv4 : décimal, octal (zéro de tête) ou
  /// hexadécimal (`0x`). `null` si la partie n'est pas un nombre.
  static BigInt? _parseNumber(String input) {
    if (input.isEmpty) return null;
    var radix = 10;
    var digits = input;
    if (digits.length >= 2 && (digits[1] == 'x' || digits[1] == 'X')) {
      if (digits[0] != '0') return null;
      radix = 16;
      digits = digits.substring(2);
    } else if (digits.length >= 2 && digits[0] == '0') {
      radix = 8;
      digits = digits.substring(1);
    }
    if (digits.isEmpty) return BigInt.zero;
    final valid = switch (radix) {
      16 => RegExp(r'^[0-9a-fA-F]+$'),
      8 => RegExp(r'^[0-7]+$'),
      _ => RegExp(r'^[0-9]+$'),
    };
    if (!valid.hasMatch(digits)) return null;
    final value = BigInt.parse(digits, radix: radix);
    return value > _tooLarge ? _tooLarge : value;
  }

  static bool _isDecimalDigit(int unit) => unit >= 0x30 && unit <= 0x39;
}
