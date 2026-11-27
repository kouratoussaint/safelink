import 'package:safelink_engine/src/url/confusables_data.g.dart';
import 'package:safelink_engine/src/url/scripts_data.g.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Écritures (latin, cyrillique, grec…) des caractères, d'après la
/// propriété Script d'Unicode.
abstract final class UnicodeScripts {
  /// Écriture des chiffres, de la ponctuation et des symboles partagés.
  static const common = 'Common';

  /// Écriture des signes combinants (accents), qui héritent de celle du
  /// caractère précédent.
  static const inherited = 'Inherited';

  /// Caractère non attribué par Unicode.
  static const unknown = 'Unknown';

  /// Version d'Unicode des données.
  static const String version = scriptsVersion;

  /// Combinaisons admises en plus d'une écriture seule (niveau « Highly
  /// Restrictive » d'UTS #39) : japonais, chinois avec bopomofo, coréen.
  static const _allowedCombinations = [
    {'Latin', 'Han', 'Hiragana', 'Katakana'},
    {'Latin', 'Han', 'Bopomofo'},
    {'Latin', 'Han', 'Hangul'},
  ];

  /// Écriture du point de code [codePoint].
  static String scriptOf(int codePoint) {
    var low = 0;
    var high = scriptRanges.length ~/ 3 - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = scriptRanges[mid * 3];
      final end = scriptRanges[mid * 3 + 1];
      if (codePoint < start) {
        high = mid - 1;
      } else if (codePoint > end) {
        low = mid + 1;
      } else {
        return scriptNames[scriptRanges[mid * 3 + 2]];
      }
    }
    return unknown;
  }

  /// Écritures présentes dans [text], hors écritures partagées (chiffres,
  /// tirets) et signes combinants.
  static Set<String> scriptsOf(String text) => {
    for (final rune in text.runes)
      if (scriptOf(rune) case final script
          when script != common && script != inherited)
        script,
  };

  /// Vrai si [text] mélange des écritures d'une façon qu'aucune langue
  /// n'emploie, par exemple du latin et du cyrillique (`pаypal` avec un « а »
  /// cyrillique).
  static bool isMixedScript(String text) {
    final scripts = scriptsOf(text);
    if (scripts.length <= 1) return false;
    return !_allowedCombinations.any((allowed) => allowed.containsAll(scripts));
  }
}

/// Caractères qui se ressemblent (UTS #39, `confusables.txt`) : `а`
/// cyrillique et `a` latin, `0` et `o`, `rn` et `m`…
abstract final class Confusables {
  /// Version d'Unicode des données.
  static const String version = confusablesVersion;

  static final Map<int, String> _prototypes = {
    for (final line in confusablesData.split('\n'))
      if (line.isNotEmpty)
        int.parse(line.substring(0, line.indexOf(':')), radix: 16): line
            .substring(line.indexOf(':') + 1),
  };

  /// Nombre de correspondances chargées.
  static int get length => _prototypes.length;

  /// « Squelette » de [text] : deux textes qui se ressemblent à l'œil ont le
  /// même squelette. Le résultat est en minuscules et n'est pas destiné à
  /// l'affichage.
  ///
  /// Avec [ignoreMarks], les accents et autres signes combinants sont
  /// retirés : `pàypal` et `paypal` ont alors le même squelette.
  static String skeleton(String text, {bool ignoreMarks = false}) {
    // Deux passes séparées par la mise en minuscules : « M » devient « m »,
    // puis « rn », comme « m » ; « I » devient « l » avant d'être minuscule.
    final firstPass = _map(unorm.nfd(text), ignoreMarks: ignoreMarks);
    return unorm.nfd(
      _map(unorm.nfd(firstPass.toLowerCase()), ignoreMarks: ignoreMarks),
    );
  }

  static String _map(String text, {required bool ignoreMarks}) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (ignoreMarks &&
          UnicodeScripts.scriptOf(rune) == UnicodeScripts.inherited) {
        continue;
      }
      final prototype = _prototypes[rune];
      if (prototype != null) {
        buffer.write(prototype);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Vrai si [text] contient des lettres d'un alphabet autre que le latin
  /// et que son squelette est entièrement ASCII : il imite alors des
  /// lettres latines (`сосо` en cyrillique). Les lettres latines accentuées
  /// (`bücher`) ne comptent pas.
  static bool imitatesAscii(String text) {
    final scripts = UnicodeScripts.scriptsOf(text);
    if (scripts.every((script) => script == 'Latin')) return false;
    return skeleton(text, ignoreMarks: true).runes.every((rune) => rune < 0x80);
  }
}
