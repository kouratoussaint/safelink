import 'package:safelink_engine/src/url/unicode_security.dart';
import 'package:test/test.dart';

void main() {
  group('UnicodeScripts', () {
    test('écriture de quelques caractères', () {
      expect(UnicodeScripts.scriptOf(0x61), 'Latin'); // a
      expect(UnicodeScripts.scriptOf(0x430), 'Cyrillic'); // \u0430
      expect(UnicodeScripts.scriptOf(0x3BF), 'Greek'); // \u03BF
      expect(UnicodeScripts.scriptOf(0x627), 'Arabic'); // ا
      expect(UnicodeScripts.scriptOf(0x4E2D), 'Han'); // 中
      expect(UnicodeScripts.scriptOf(0x30), UnicodeScripts.common); // 0
      expect(UnicodeScripts.scriptOf(0x301), UnicodeScripts.inherited);
      expect(UnicodeScripts.scriptOf(0x10FFFF), UnicodeScripts.unknown);
      expect(UnicodeScripts.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('écritures d’un texte, hors chiffres et accents', () {
      expect(UnicodeScripts.scriptsOf('paypal-2024'), {'Latin'});
      expect(UnicodeScripts.scriptsOf('p\u0430ypal'), {'Latin', 'Cyrillic'});
      expect(UnicodeScripts.scriptsOf('123-456'), isEmpty);
      expect(UnicodeScripts.scriptsOf('é'), {'Latin'});
    });

    test('mélanges interdits et combinaisons admises', () {
      expect(UnicodeScripts.isMixedScript('paypal'), isFalse);
      expect(
        UnicodeScripts.isMixedScript('\u043F\u0440\u0438\u043C\u0435\u0440'),
        isFalse,
      );
      expect(UnicodeScripts.isMixedScript('bücher'), isFalse);
      expect(UnicodeScripts.isMixedScript('p\u0430ypal'), isTrue);
      expect(UnicodeScripts.isMixedScript('g\u03BF\u03BFgle'), isTrue);
      // Japonais : kanji, kana et latin ensemble sont usuels.
      expect(UnicodeScripts.isMixedScript('東京ガスtokyo'), isFalse);
      expect(UnicodeScripts.isMixedScript('서울seoul中'), isFalse);
      expect(UnicodeScripts.isMixedScript('中文ㄅ'), isFalse);
      expect(UnicodeScripts.isMixedScript('中文\u0430'), isTrue);
    });
  });

  group('Confusables', () {
    test('caractères qui imitent des lettres latines', () {
      expect(Confusables.skeleton('p\u0430yp\u0430l'), 'paypal');
      expect(Confusables.skeleton('paypa1'), 'paypal');
      expect(Confusables.skeleton('g00gle'), 'google');
      expect(Confusables.skeleton('\u0445.com'), 'x.corn');
      expect(
        Confusables.skeleton('rnicrosoft'),
        Confusables.skeleton('microsoft'),
      );
      expect(Confusables.skeleton('PAYPAL'), Confusables.skeleton('paypal'));
      expect(Confusables.length, greaterThan(1000));
      expect(Confusables.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('accents conservés ou retirés', () {
      expect(Confusables.skeleton('pàypal'), isNot('paypal'));
      expect(Confusables.skeleton('pàypal', ignoreMarks: true), 'paypal');
      expect(Confusables.skeleton('orangé', ignoreMarks: true), 'orange');
    });

    test('caractères sans équivalent laissés tels quels', () {
      expect(Confusables.skeleton('中文'), '中文');
    });

    test('imitation de l’ASCII', () {
      expect(Confusables.imitatesAscii('\u0441\u043E\u0441\u043E'), isTrue);
      expect(Confusables.imitatesAscii('p\u0430ypal'), isTrue);
      expect(Confusables.imitatesAscii('paypal'), isFalse);
      expect(
        Confusables.imitatesAscii('\u043F\u0440\u0438\u043C\u0435\u0440'),
        isFalse,
      );
      expect(Confusables.imitatesAscii('中文'), isFalse);
    });
  });
}
