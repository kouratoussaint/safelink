/// Encodage Punycode (RFC 3492), utilisé par les noms de domaine
/// internationaux : `bücher` ↔ `bcher-kva`.
///
/// Implémentation directe de l'algorithme « Bootstring » avec les paramètres
/// de la section 5 de la RFC, sans dépendance. Les entrées invalides lèvent
/// une [FormatException] ; aucune n'est corrigée silencieusement.
abstract final class Punycode {
  static const _base = 36;
  static const _tMin = 1;
  static const _tMax = 26;
  static const _skew = 38;
  static const _damp = 700;
  static const _initialBias = 72;
  static const _initialN = 128;
  static const _delimiter = 0x2D; // « - »
  static const _maxCodePoint = 0x10FFFF;

  /// Plus grand entier manipulé, comme dans l'implémentation de référence
  /// de la RFC (32 bits non signés), pour détecter les débordements.
  static const _maxInt = 0xFFFFFFFF;

  /// Encode [input] (une suite de caractères Unicode) en Punycode.
  ///
  /// Les caractères ASCII sont recopiés tels quels, casse comprise.
  static String encode(String input) {
    final codePoints = input.runes.toList();
    final output = <int>[];
    for (final c in codePoints) {
      if (c < 0x80) output.add(c);
    }
    final basicCount = output.length;
    var handled = basicCount;
    if (basicCount > 0) output.add(_delimiter);

    var n = _initialN;
    var delta = 0;
    var bias = _initialBias;
    while (handled < codePoints.length) {
      var m = _maxCodePoint + 1;
      for (final c in codePoints) {
        if (c >= n && c < m) m = c;
      }
      final increment = (m - n) * (handled + 1);
      if (increment > _maxInt - delta) {
        throw const FormatException('Débordement pendant l’encodage.');
      }
      delta += increment;
      n = m;
      for (final c in codePoints) {
        if (c < n) {
          delta++;
          if (delta > _maxInt) {
            throw const FormatException('Débordement pendant l’encodage.');
          }
        }
        if (c == n) {
          var q = delta;
          for (var k = _base; ; k += _base) {
            final t = _threshold(k, bias);
            if (q < t) break;
            output.add(_digit(t + (q - t) % (_base - t)));
            q = (q - t) ~/ (_base - t);
          }
          output.add(_digit(q));
          bias = _adapt(delta, handled + 1, firstTime: handled == basicCount);
          delta = 0;
          handled++;
        }
      }
      delta++;
      n++;
    }
    return String.fromCharCodes(output);
  }

  /// Décode [input] (Punycode, sans le préfixe `xn--`).
  ///
  /// Lève une [FormatException] si l'entrée contient un caractère non ASCII,
  /// un chiffre invalide, une séquence tronquée ou un débordement.
  static String decode(String input) {
    final units = input.codeUnits;
    for (final u in units) {
      if (u >= 0x80) {
        throw const FormatException('Caractère non ASCII dans du Punycode.');
      }
    }
    final delimiterIndex = input.lastIndexOf('-');
    final output = <int>[
      if (delimiterIndex > 0) ...units.sublist(0, delimiterIndex),
    ];
    var index = delimiterIndex > 0 ? delimiterIndex + 1 : 0;

    var n = _initialN;
    var i = 0;
    var bias = _initialBias;
    while (index < units.length) {
      final oldI = i;
      var w = 1;
      for (var k = _base; ; k += _base) {
        if (index >= units.length) {
          throw const FormatException('Punycode tronqué.');
        }
        final digit = _digitValue(units[index++]);
        if (digit < 0) {
          throw const FormatException('Chiffre Punycode invalide.');
        }
        if (digit > (_maxInt - i) ~/ w) {
          throw const FormatException('Débordement pendant le décodage.');
        }
        i += digit * w;
        final t = _threshold(k, bias);
        if (digit < t) break;
        if (w > _maxInt ~/ (_base - t)) {
          throw const FormatException('Débordement pendant le décodage.');
        }
        w *= _base - t;
      }
      final length = output.length + 1;
      bias = _adapt(i - oldI, length, firstTime: oldI == 0);
      if (i ~/ length > _maxInt - n) {
        throw const FormatException('Débordement pendant le décodage.');
      }
      n += i ~/ length;
      i %= length;
      if (n > _maxCodePoint || (n >= 0xD800 && n <= 0xDFFF)) {
        throw const FormatException('Point de code invalide.');
      }
      output.insert(i, n);
      i++;
    }
    return String.fromCharCodes(output);
  }

  static int _threshold(int k, int bias) {
    if (k <= bias + _tMin) return _tMin;
    if (k >= bias + _tMax) return _tMax;
    return k - bias;
  }

  static int _adapt(int delta, int numPoints, {required bool firstTime}) {
    var d = firstTime ? delta ~/ _damp : delta ~/ 2;
    d += d ~/ numPoints;
    var k = 0;
    while (d > ((_base - _tMin) * _tMax) ~/ 2) {
      d ~/= _base - _tMin;
      k += _base;
    }
    return k + (((_base - _tMin + 1) * d) ~/ (d + _skew));
  }

  /// Chiffre 0–25 → « a »–« z », 26–35 → « 0 »–« 9 ».
  static int _digit(int d) => d < 26 ? 0x61 + d : 0x30 + d - 26;

  /// Valeur d'un chiffre, quelle que soit sa casse ; -1 si invalide.
  static int _digitValue(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30 + 26;
    if (c >= 0x41 && c <= 0x5A) return c - 0x41;
    if (c >= 0x61 && c <= 0x7A) return c - 0x61;
    return -1;
  }
}
