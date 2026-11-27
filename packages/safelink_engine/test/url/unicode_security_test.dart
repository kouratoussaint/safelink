import 'package:safelink_engine/src/url/unicode_security.dart';
import 'package:test/test.dart';

void main() {
  group('UnicodeScripts', () {
    test('écriture de quelques caractères', () {
      expect(UnicodeScripts.scriptOf(0x61), 'Latin'); // a
      expect(UnicodeScripts.scriptOf(0x430), 'Cyrillic'); // а
      expect(UnicodeScripts.scriptOf(0x3BF), 'Greek'); // ο
      expect(UnicodeScripts.scriptOf(0x627), 'Arabic'); // ا
      expect(UnicodeScripts.scriptOf(0x4E2D), 'Han'); // 中
      expect(UnicodeScripts.scriptOf(0x30), UnicodeScripts.common); // 0
      expect(UnicodeScripts.scriptOf(0x301), UnicodeScripts.inherited);
      expect(UnicodeScripts.scriptOf(0x10FFFF), UnicodeScripts.unknown);
      expect(UnicodeScripts.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('écritures d’un texte, hors chiffres et accents', () {
      expect(UnicodeScripts.scriptsOf('paypal-2024'), {'Latin'});
      expect(UnicodeScripts.scriptsOf('pаypal'), {'Latin', 'Cyrillic'});
      expect(UnicodeScripts.scriptsOf('123-456'), isEmpty);
      expect(UnicodeScripts.scriptsOf('é'), {'Latin'});
    });

    test('mélanges interdits et combinaisons admises', () {
      expect(UnicodeScripts.isMixedScript('paypal'), isFalse);
      expect(UnicodeScripts.isMixedScript('пример'), isFalse);
      expect(UnicodeScripts.isMixedScript('bücher'), isFalse);
      expect(UnicodeScripts.isMixedScript('pаypal'), isTrue);
      expect(UnicodeScripts.isMixedScript('gοοgle'), isTrue);
      // Japonais : kanji, kana et latin ensemble sont usuels.
      expect(UnicodeScripts.isMixedScript('東京ガスtokyo'), isFalse);
      expect(UnicodeScripts.isMixedScript('서울seoul中'), isFalse);
      expect(UnicodeScripts.isMixedScript('中文ㄅ'), isFalse);
      expect(UnicodeScripts.isMixedScript('中文а'), isTrue);
    });
  });

  group('Confusables', () {
    test('caractères qui imitent des lettres latines', () {
      expect(Confusables.skeleton('pаypаl'), 'paypal');
      expect(Confusables.skeleton('paypa1'), 'paypal');
      expect(Confusables.skeleton('g00gle'), 'google');
      expect(Confusables.skeleton('х.com'), 'x.corn');
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
      expect(Confusables.imitatesAscii('сосо'), isTrue);
      expect(Confusables.imitatesAscii('pаypal'), isTrue);
      expect(Confusables.imitatesAscii('paypal'), isFalse);
      expect(Confusables.imitatesAscii('пример'), isFalse);
      expect(Confusables.imitatesAscii('中文'), isFalse);
    });
  });
}
