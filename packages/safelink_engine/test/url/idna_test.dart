import 'package:safelink_engine/src/url/idna.dart';
import 'package:test/test.dart';

void main() {
  group('Idna.toAscii', () {
    test('ASCII inchangé, mis en minuscules', () {
      expect(Idna.toAscii('Example.COM'), 'example.com');
    });

    test('labels internationaux encodés en Punycode', () {
      expect(Idna.toAscii('bücher.example'), 'xn--bcher-kva.example');
      expect(Idna.toAscii('食狮.公司.cn'), 'xn--85x722f.xn--55qx5d.cn');
    });

    test('lettres pleine chasse ramenées à l’ASCII (NFKC)', () {
      expect(
        Idna.toAscii('\uFF47\uFF4F\uFF4F\uFF47\uFF4C\uFF45.com'),
        'google.com',
      );
    });

    test('séparateurs idéographiques ramenés au point', () {
      expect(Idna.toAscii('example\u3002com'), 'example.com');
      expect(Idna.toAscii('example\uFF0Ecom'), 'example.com');
      expect(Idna.toAscii('example\uFF61com'), 'example.com');
    });

    test('point final unique accepté', () {
      expect(Idna.toAscii('example.com.'), 'example.com');
    });

    test('noms invalides', () {
      expect(Idna.toAscii(''), isNull);
      expect(Idna.toAscii('.'), isNull);
      expect(Idna.toAscii('.example.com'), isNull);
      expect(Idna.toAscii('a..b'), isNull);
      expect(Idna.toAscii('example.com..'), isNull);
    });

    test('limites de longueur', () {
      final label63 = 'a' * 63;
      expect(Idna.toAscii('$label63.com'), '$label63.com');
      expect(Idna.toAscii('${'a' * 64}.com'), isNull);
      // Un label Unicode dont la forme Punycode dépasse 63 caractères.
      // 57 « é » donnent « xn-- » + 59 caractères = 63 ; 58 en donnent 64.
      expect(Idna.toAscii('${'é' * 57}.com'), isNotNull);
      expect(Idna.toAscii('${'é' * 58}.com'), isNull);
      final long = List.filled(4, label63).join('.'); // 255 caractères
      expect(Idna.toAscii(long), isNull);
      final ok = [...List.filled(3, label63), 'a' * 61].join('.');
      expect(ok.length, 253);
      expect(Idna.toAscii(ok), ok);
    });
  });

  group('Idna.toUnicode et décodage', () {
    test('décode les labels xn--', () {
      expect(Idna.toUnicode('xn--bcher-kva.example'), 'bücher.example');
      expect(Idna.toUnicode('XN--BCHER-KVA.example'), 'bücher.example');
    });

    test('laisse les labels invalides tels quels', () {
      expect(Idna.toUnicode('xn--k!a.example'), 'xn--k!a.example');
      expect(Idna.decodeLabel('xn--k!a'), isNull);
      expect(Idna.decodeLabel('xn--'), isNull);
      expect(Idna.decodeLabel('example'), isNull);
    });

    test('isValidAce', () {
      expect(Idna.isValidAce('xn--bcher-kva.example'), isTrue);
      expect(Idna.isValidAce('example.com'), isTrue);
      expect(Idna.isValidAce('xn--zz.example'), isFalse);
    });

    test('aller-retour', () {
      for (final domain in [
        'bücher.example',
        '食狮.中国',
        '\u043F\u0440\u0438\u043C\u0435\u0440.\u0440\u0444',
      ]) {
        expect(Idna.toUnicode(Idna.toAscii(domain)!), domain);
      }
    });
  });
}
