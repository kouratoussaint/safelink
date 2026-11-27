import 'package:safelink_engine/src/url/percent_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('PercentEncoding.decode', () {
    test('séquences valides, casse quelconque', () {
      expect(PercentEncoding.decodeStrict('%41%62%c3%a9'), 'Abé');
      expect(PercentEncoding.decodeStrict('caf%C3%A9'), 'café');
    });

    test('caractères non ASCII mêlés aux séquences', () {
      expect(PercentEncoding.decodeStrict('é%20😀%21'), 'é 😀!');
      expect(PercentEncoding.decodeToBytes('😀'), [0xF0, 0x9F, 0x98, 0x80]);
    });

    test('« % » isolé ou incomplet conservé', () {
      expect(PercentEncoding.decodeStrict('100%'), '100%');
      expect(PercentEncoding.decodeStrict('%4'), '%4');
      expect(PercentEncoding.decodeStrict('%G1'), '%G1');
      expect(PercentEncoding.decodeStrict('%%41'), '%A');
    });

    test('UTF-8 invalide : refus strict, remplacement souple', () {
      expect(PercentEncoding.decodeStrict('%FF'), isNull);
      expect(PercentEncoding.decodeLenient('a%FFb'), 'a�b');
    });

    test('« + » devient une espace seulement pour les paramètres', () {
      expect(PercentEncoding.decodeLenient('a+b'), 'a+b');
      expect(PercentEncoding.decodeLenient('a+b', plusAsSpace: true), 'a b');
      expect(PercentEncoding.decodeLenient('a%2Bb', plusAsSpace: true), 'a+b');
    });
  });

  group('PercentEncoding.encode', () {
    test('UTF-8 en majuscules, « % » existants conservés', () {
      expect(
        PercentEncoding.encode('é 😀%20', PercentEncoding.pathSet),
        '%C3%A9%20%F0%9F%98%80%20',
      );
      expect(PercentEncoding.encode('\u0001', PercentEncoding.pathSet), '%01');
    });

    test('ensembles du standard URL', () {
      const sample = '"#\'<>?`{}/:;=@[\\]^|';
      expect(
        PercentEncoding.encode(sample, PercentEncoding.fragmentSet),
        r"%22#'%3C%3E?%60{}/:;=@[\]^|",
      );
      expect(
        PercentEncoding.encode(sample, PercentEncoding.querySet),
        r'%22%23%27%3C%3E?`{}/:;=@[\]^|',
      );
      expect(
        PercentEncoding.encode(sample, PercentEncoding.pathSet),
        r"%22%23'%3C%3E%3F%60%7B%7D/:;=@[\]^|",
      );
      expect(
        PercentEncoding.encode(sample, PercentEncoding.userinfoSet),
        "%22%23'%3C%3E%3F%60%7B%7D%2F%3A%3B%3D%40%5B%5C%5D%5E%7C",
      );
    });
  });
}
