import 'dart:io';

import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';
import 'package:test/test.dart';

/// Domaine enregistrable de [input] selon la convention des tests officiels :
/// `null` pour une entrée invalide ou un suffixe public, résultat en Unicode
/// si l'entrée l'était.
String? registrableDomain(PublicSuffixList psl, String? input) {
  if (input == null) return null;
  final ascii = Idna.toAscii(input);
  if (ascii == null || input.startsWith('.')) return null;
  final registrable = psl.lookup(ascii)?.registrableDomain;
  if (registrable == null) return null;
  final isUnicode = input.codeUnits.any((u) => u >= 0x80);
  return isUnicode ? Idna.toUnicode(registrable) : registrable;
}

void main() {
  final psl = PublicSuffixList.embedded;

  group('tests officiels de la Public Suffix List', () {
    final lines = File('test/data/psl_tests.txt').readAsLinesSync();
    var count = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//')) continue;
      final parts = line.split(RegExp(r'\s+'));
      final input = parts[0] == 'null' ? null : parts[0];
      final expected = parts[1] == 'null' ? null : parts[1];
      count++;
      test('$input → $expected', () {
        expect(registrableDomain(psl, input), expected);
      });
    }
    test('le fichier de tests est complet', () {
      expect(count, greaterThanOrEqualTo(70));
    });
  });

  group('liste embarquée', () {
    test('contient les deux sections', () {
      expect(psl.length, greaterThan(9000));
      expect(psl.retrievedOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('suffixes utiles au Burkina Faso et à la région', () {
      expect(psl.lookup('sonabel.bf')?.registrableDomain, 'sonabel.bf');
      expect(psl.lookup('www.gov.bf')?.registrableDomain, 'www.gov.bf');
      expect(psl.lookup('orange.ci')?.registrableDomain, 'orange.ci');
      expect(psl.lookup('a.b.co.ci')?.registrableDomain, 'b.co.ci');
    });

    test('section privée : sous-domaines d’hébergeurs distincts', () {
      final match = psl.lookup('arnaque.blogspot.com')!;
      expect(match.publicSuffix, 'blogspot.com');
      expect(match.registrableDomain, 'arnaque.blogspot.com');
      expect(match.isPrivateSuffix, isTrue);
      expect(match.isListed, isTrue);

      final icann = psl.lookup('www.example.co.uk')!;
      expect(icann.registrableDomain, 'example.co.uk');
      expect(icann.isPrivateSuffix, isFalse);
    });

    test('extension inconnue : règle par défaut', () {
      final match = psl.lookup('site.inexistant')!;
      expect(match.publicSuffix, 'inexistant');
      expect(match.registrableDomain, 'site.inexistant');
      expect(match.isListed, isFalse);
    });

    test('noms invalides', () {
      expect(psl.lookup(''), isNull);
      expect(psl.lookup('a..com'), isNull);
    });
  });

  group('PublicSuffixList.fromRules', () {
    final custom = PublicSuffixList.fromRules(
      icannRules: 'test\n*.wild.test\n!keep.wild.test\n\n',
      privateRules: 'host.test',
    );

    test('règles normales, jokers et exceptions', () {
      expect(custom.length, 4);
      expect(custom.retrievedOn, 'inconnue');
      expect(custom.lookup('a.test')?.registrableDomain, 'a.test');
      expect(
        custom.lookup('x.y.wild.test')?.registrableDomain,
        'x.y.wild.test',
      );
      expect(custom.lookup('y.wild.test')?.registrableDomain, isNull);
      expect(
        custom.lookup('keep.wild.test')?.registrableDomain,
        'keep.wild.test',
      );
      expect(
        custom.lookup('a.keep.wild.test')?.registrableDomain,
        'keep.wild.test',
      );
      expect(custom.lookup('me.host.test')?.isPrivateSuffix, isTrue);
    });

    test('égalité et affichage', () {
      final a = custom.lookup('a.test');
      final b = custom.lookup('b.a.test');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(custom.lookup('me.host.test')));
      expect(a.toString(), 'PublicSuffixMatch(test, a.test)');
      expect(custom.lookup('test').toString(), 'PublicSuffixMatch(test, -)');
    });
  });
}
