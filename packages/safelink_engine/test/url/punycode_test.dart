import 'package:safelink_engine/src/url/punycode.dart';
import 'package:test/test.dart';

import 'rfc3492_vectors.dart';

void main() {
  group('Punycode, vecteurs de la RFC 3492', () {
    for (final (unicode, ascii) in rfc3492Vectors) {
      test('encode puis décode « $ascii »', () {
        // La RFC note certains chiffres en majuscules (annotation de casse) :
        // l'encodeur produit des minuscules, la comparaison ignore la casse.
        expect(Punycode.encode(unicode).toLowerCase(), ascii.toLowerCase());
        expect(Punycode.decode(ascii), unicode);
        expect(Punycode.decode(Punycode.encode(unicode)), unicode);
      });
    }
  });

  group('Punycode, cas usuels', () {
    test('noms de domaine courants', () {
      expect(Punycode.encode('bücher'), 'bcher-kva');
      expect(Punycode.decode('bcher-kva'), 'bücher');
      expect(Punycode.encode('münchen'), 'mnchen-3ya');
      expect(Punycode.encode('ñ'), 'ida');
    });

    test('chaîne vide et chaîne ASCII', () {
      expect(Punycode.encode(''), '');
      expect(Punycode.decode(''), '');
      expect(Punycode.encode('abc'), 'abc-');
      expect(Punycode.decode('abc-'), 'abc');
    });

    test('caractères hors du plan multilingue de base', () {
      const emoji = '😀';
      expect(Punycode.decode(Punycode.encode(emoji)), emoji);
    });

    test('les chiffres en majuscules sont acceptés', () {
      expect(Punycode.decode('BCHER-KVA'), 'BüCHER');
    });
  });

  group('Punycode, entrées invalides', () {
    test('caractère non ASCII', () {
      expect(() => Punycode.decode('bü-kva'), throwsFormatException);
    });

    test('chiffre invalide', () {
      expect(() => Punycode.decode('abc-k!a'), throwsFormatException);
    });

    test('séquence tronquée', () {
      // « z » a la valeur 25, au-dessus du seuil : un chiffre doit suivre.
      expect(() => Punycode.decode('abc-z'), throwsFormatException);
    });

    test('débordement', () {
      expect(() => Punycode.decode('99999999999999'), throwsFormatException);
    });

    test('point de code hors limites ou demi-substitut', () {
      // Deltas encodés à la main : « tda » donne U+00FC (contrôle),
      // « en32g » viserait U+110000 et « ib9b » le demi-substitut U+D800.
      expect(Punycode.decode('tda'), 'ü');
      expect(() => Punycode.decode('en32g'), throwsFormatException);
      expect(() => Punycode.decode('ib9b'), throwsFormatException);
    });
  });
}
