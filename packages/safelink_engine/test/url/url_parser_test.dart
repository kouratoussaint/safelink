import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';
import 'package:safelink_engine/src/url/url_parser.dart';
import 'package:test/test.dart';

final _parser = UrlParser();

ParsedUrl parsed(String input) {
  final result = _parser.parse(input);
  expect(result, isA<ParsedUrl>(), reason: 'échec inattendu pour « $input »');
  return result as ParsedUrl;
}

UrlParseFailure failed(String input, {UrlParser? parser}) {
  final result = (parser ?? _parser).parse(input);
  expect(result, isA<UrlParseFailure>(), reason: '« $input » accepté');
  return result as UrlParseFailure;
}

void main() {
  group('liens usuels', () {
    test('https simple', () {
      final url = parsed('https://example.com');
      expect(url.scheme, 'https');
      expect(url.host, 'example.com');
      expect(url.hostType, UrlHostType.domain);
      expect(url.path, '/');
      expect(url.query, isNull);
      expect(url.fragment, isNull);
      expect(url.port, isNull);
      expect(url.effectivePort, 443);
      expect(url.href, 'https://example.com/');
      expect(url.normalizations, isEmpty);
      expect(url.hasExplicitScheme, isTrue);
      expect(url.hasCredentials, isFalse);
      expect(url.registrableDomain, 'example.com');
      expect(url.input, 'https://example.com');
    });

    test('casse, port par défaut et segments « .. »', () {
      final url = parsed('HTTP://WWW.Example.COM:80/a/./b/../c?x=1#f');
      expect(url.scheme, 'http');
      expect(url.host, 'www.example.com');
      expect(url.port, isNull);
      expect(url.effectivePort, 80);
      expect(url.path, '/a/c');
      expect(url.query, 'x=1');
      expect(url.fragment, 'f');
      expect(url.normalizations, {
        UrlNormalization.defaultPortRemoved,
        UrlNormalization.dotSegmentsResolved,
      });
      expect(url.href, 'http://www.example.com/a/c?x=1#f');
    });

    test('port explicite conservé', () {
      final url = parsed('https://example.com:8443/x');
      expect(url.port, 8443);
      expect(url.effectivePort, 8443);
      expect(url.href, 'https://example.com:8443/x');
      expect(parsed('https://example.com:0443').port, isNull);
      expect(parsed('https://example.com:').port, isNull);
    });

    test('requête et fragment sans chemin', () {
      expect(parsed('https://example.com?q=1').path, '/');
      expect(parsed('https://example.com?q=1').query, 'q=1');
      expect(parsed('https://example.com#x').fragment, 'x');
      expect(parsed('https://example.com/?').query, '');
    });

    test('domaine enregistrable avec la Public Suffix List', () {
      expect(
        parsed('https://www.impots.gouv.bf/').registrableDomain,
        'gouv.bf',
      );
      expect(
        parsed('https://faux-colis.blogspot.com').registrableDomain,
        'faux-colis.blogspot.com',
      );
      final unknown = parsed('https://site.inexistant/');
      expect(unknown.publicSuffix?.isListed, isFalse);
      expect(parsed('https://intranet/').registrableDomain, isNull);
    });
  });

  group('lien sans protocole', () {
    test('https supposé et signalé', () {
      final url = parsed('example.com/promo');
      expect(url.scheme, 'https');
      expect(url.hasExplicitScheme, isFalse);
      expect(url.normalizations, {UrlNormalization.schemeAdded});
      expect(url.href, 'https://example.com/promo');
    });

    test('avec port ou double barre', () {
      expect(parsed('www.example.com:8080/x').port, 8080);
      expect(parsed('example.com:443/x').port, isNull);
      expect(parsed('//example.com/x').host, 'example.com');
    });

    test('ce qui ne ressemble pas à un lien est refusé', () {
      for (final text in [
        'bonjour',
        'bonjour à tous',
        'fichier.txt',
        'localhost:3000',
        '/chemin/seul',
        r'\\serveur\partage',
        '///example.com',
        'exa mple.com',
      ]) {
        expect(failed(text).error, UrlParseError.notAUrl, reason: text);
      }
    });

    test('adresse e-mail', () {
      expect(failed('jean@example.com').error, UrlParseError.emailAddress);
    });

    test('port invalide', () {
      expect(failed('example.com:abc').error, UrlParseError.invalidPort);
    });
  });

  group('schémas non web', () {
    test('déclarés non analysables, schéma conservé', () {
      for (final (text, scheme) in [
        ('mailto:jean@example.com', 'mailto'),
        ('javascript:alert(1)', 'javascript'),
        ('JavaScript:void(0)', 'javascript'),
        ('tel:70123456', 'tel'),
        ('tel:+22670123456', 'tel'),
        ('sms:70123456?body=code', 'sms'),
        ('data:text/html,<b>x</b>', 'data'),
        ('ftp://example.com/f', 'ftp'),
        ('intent://scan#Intent;scheme=zxing;end', 'intent'),
        ('whatsapp://send?text=x', 'whatsapp'),
        ('file:///sdcard/a.apk', 'file'),
        ('hxxp://example.com', 'hxxp'),
        ('com.example.app:/callback', 'com.example.app'),
      ]) {
        final failure = failed(text);
        expect(failure.error, UrlParseError.nonWebScheme, reason: text);
        expect(failure.scheme, scheme, reason: text);
      }
    });
  });

  group('identifiants avant « @ »', () {
    test('le vrai site est après le @', () {
      final url = parsed('https://www.paypal.com@evil.example/login');
      expect(url.host, 'evil.example');
      expect(url.username, 'www.paypal.com');
      expect(url.password, isNull);
      expect(url.hasCredentials, isTrue);
      expect(url.href, 'https://www.paypal.com@evil.example/login');
    });

    test('mot de passe et @ multiples', () {
      final url = parsed('https://user:pa ss@host.com/');
      expect(url.username, 'user');
      expect(url.password, 'pa%20ss');
      expect(url.normalizations, {UrlNormalization.percentEncodingAdded});
      expect(parsed('https://a@b@c.com').username, 'a%40b');
      expect(parsed('https://a@b@c.com').host, 'c.com');
      expect(parsed('https://@c.com').hasCredentials, isTrue);
      expect(parsed('https://:x@c.com').href, 'https://:x@c.com/');
    });
  });

  group('adresses IPv4', () {
    test('formes trompeuses ramenées à a.b.c.d', () {
      for (final text in [
        'http://3232235777/',
        'http://0xC0.0xA8.0x01.0x01/',
        'http://0300.0250.1.1/',
        'http://192.168.257/',
        'http://0xc0a80101/',
      ]) {
        final url = parsed(text);
        expect(url.host, '192.168.1.1', reason: text);
        expect(url.hostType, UrlHostType.ipv4, reason: text);
        expect(
          url.normalizations,
          contains(UrlNormalization.ipv4Canonicalized),
          reason: text,
        );
      }
      expect(parsed('http://127.1').host, '127.0.0.1');
      expect(parsed('http://192.168.1.1./').normalizations, {
        UrlNormalization.trailingDotRemoved,
      });
      // « 0xx » n'est pas un nombre : c'est un nom de domaine (WHATWG).
      expect(parsed('http://1.2.3.0xx/').hostType, UrlHostType.domain);
      expect(parsed('http://0x/').host, '0.0.0.0');
    });

    test('forme usuelle sans transformation', () {
      final url = parsed('http://8.8.8.8/');
      expect(url.normalizations, isEmpty);
      expect(url.publicSuffix, isNull);
      expect(url.registrableDomain, isNull);
      expect(url.hostUnicode, '8.8.8.8');
      expect(parsed('8.8.8.8/x').host, '8.8.8.8');
    });

    test('adresses invalides refusées', () {
      for (final text in [
        'http://256.256.256.256/',
        'http://1.2.3.4.5/',
        'http://08.1.1.1/',
        'http://0x1g.1.1.1/',
        'http://example.1/',
        'http://4294967296/',
        'http://1.2.3.999999999999999999/',
        'http://1.2.3.09/',
      ]) {
        expect(failed(text).error, UrlParseError.invalidHost, reason: text);
      }
    });
  });

  group('adresses IPv6', () {
    test('forme compressée', () {
      final url = parsed('http://[2001:DB8:0:0:0:0:0:1]:8080/x');
      expect(url.host, '[2001:db8::1]');
      expect(url.hostType, UrlHostType.ipv6);
      expect(url.port, 8080);
      expect(url.hostUnicode, '[2001:db8::1]');
      expect(parsed('http://[::1]/').host, '[::1]');
      expect(parsed('http://[::]/').host, '[::]');
      expect(parsed('http://[1:0:0:2:0:0:0:3]/').host, '[1:0:0:2::3]');
      expect(parsed('http://[1:0:0:2:3:4:5:6]/').host, '[1::2:3:4:5:6]');
      expect(parsed('http://[1:2:3:4:5:6:7:0]/').host, '[1:2:3:4:5:6:7:0]');
      expect(parsed('http://[::ffff:192.168.1.1]/').host, '[::ffff:c0a8:101]');
      expect(parsed('[::1]/x').host, '[::1]');
    });

    test('adresses invalides refusées', () {
      for (final text in [
        'http://[zz]/',
        'http://[::1/',
        'http://[::1]x/',
        'http://[1:2:3:4:5:6:7:8:9]/',
      ]) {
        expect(failed(text).error, UrlParseError.invalidHost, reason: text);
      }
    });
  });

  group('noms de domaine', () {
    test('international : Punycode et forme lisible', () {
      final url = parsed('https://bücher.example/');
      expect(url.host, 'xn--bcher-kva.example');
      expect(url.hostUnicode, 'bücher.example');
      expect(url.isInternationalized, isTrue);
      expect(
        url.normalizations,
        contains(UrlNormalization.hostConvertedToPunycode),
      );
      final ace = parsed('https://xn--bcher-kva.example/');
      expect(ace.isInternationalized, isTrue);
      expect(ace.normalizations, isEmpty);
      expect(parsed('https://example.com').isInternationalized, isFalse);
      expect(parsed('http://1.2.3.4').isInternationalized, isFalse);
    });

    test('lettres pleine chasse', () {
      final url = parsed('https://\uFF50\uFF41\uFF59\uFF50\uFF41\uFF4C.com/');
      expect(url.host, 'paypal.com');
      expect(
        url.normalizations,
        contains(UrlNormalization.hostCharactersNormalized),
      );
      expect(parsed('https://\uFF21\uFF22\uFF23.com').host, 'abc.com');
    });

    test('codes %XX dans le nom', () {
      final url = parsed('https://exa%6Dple.com/');
      expect(url.host, 'example.com');
      expect(url.normalizations, {UrlNormalization.hostPercentDecoded});
      expect(parsed('https://%62%C3%BC.example').host, 'xn--b-eha.example');
    });

    test('caractères invisibles retirés', () {
      final url = parsed('https://pay\u00ADpal.com/');
      expect(url.host, 'paypal.com');
      expect(
        url.normalizations,
        contains(UrlNormalization.invisibleCharactersRemoved),
      );
      expect(parsed('https://pay\u200Bpal.com').host, 'paypal.com');
    });

    test('point final retiré', () {
      final url = parsed('https://example.com./');
      expect(url.host, 'example.com');
      expect(url.normalizations, {UrlNormalization.trailingDotRemoved});
    });

    test('noms invalides refusés', () {
      for (final text in [
        'https://pay\u202Epal.com/',
        'https://evil.com\uFF0Fpaypal.com/',
        'https://exa%ZZ.com/',
        'https://exa%FF.com/',
        'https://exa mple.com/',
        'https://a..b.com/',
        'https://${'a' * 64}.com/',
        'https://xn--zz.example/',
        'https://exa^mple.com/',
        'https:///',
        'https://user@/',
        'https://:443/',
      ]) {
        expect(failed(text).error, UrlParseError.invalidHost, reason: text);
      }
    });
  });

  group('barres obliques et blancs', () {
    test('barres inversées ou en nombre inhabituel', () {
      final url = parsed(r'https:\\example.com\a\b');
      expect(url.host, 'example.com');
      expect(url.path, '/a/b');
      expect(url.normalizations, {UrlNormalization.slashesNormalized});
      expect(parsed('https:example.com').normalizations, {
        UrlNormalization.slashesNormalized,
      });
      expect(parsed('https:///example.com').normalizations, {
        UrlNormalization.slashesNormalized,
      });
      expect(parsed(r'https://example.com/a\b').normalizations, {
        UrlNormalization.slashesNormalized,
      });
      expect(parsed(r'https://example.com/a?b\c').query, r'b\c');
    });

    test('tabulations et retours à la ligne retirés', () {
      final url = parsed('https://exa\tmple.com/a\nb');
      expect(url.host, 'example.com');
      expect(url.path, '/ab');
      expect(url.normalizations, {UrlNormalization.whitespaceRemoved});
      expect(parsed('  https://example.com  ').normalizations, isEmpty);
    });
  });

  group('encodage du chemin, de la requête et du fragment', () {
    test('espaces et caractères non ASCII', () {
      final url = parsed('https://example.com/a b/café?c d=é#e f');
      expect(url.path, '/a%20b/caf%C3%A9');
      expect(url.query, 'c%20d=%C3%A9');
      expect(url.fragment, 'e%20f');
      expect(url.normalizations, {UrlNormalization.percentEncodingAdded});
      expect(parsed('https://example.com/%41').path, '/%41');
      expect(parsed('https://e.com/{x}`').path, '/%7Bx%7D%60');
      expect(parsed("https://e.com/?a='").query, 'a=%27');
      expect(parsed("https://e.com/#a'").fragment, "a'");
    });

    test('segments encodés « %2e »', () {
      final url = parsed('https://example.com/a/%2e%2E/x');
      expect(url.path, '/x');
      expect(parsed('https://e.com/a/.%2e').path, '/');
      expect(parsed('https://e.com/a/%2e./b').path, '/b');
      expect(parsed('https://e.com/a/%2e/b').path, '/a/b');
      expect(parsed('https://e.com/a/./').path, '/a/');
      expect(parsed('https://e.com/..').path, '/');
      expect(parsed('https://e.com/a/.').path, '/a/');
    });

    test('paramètres décodés', () {
      final url = parsed('https://e.com/?a=1&b=&c&&d=x%20y+z&e=%ZZ&=v');
      expect(url.queryParameters, const [
        QueryParameter('a', '1'),
        QueryParameter('b', ''),
        QueryParameter('c', ''),
        QueryParameter('d', 'x y z'),
        QueryParameter('e', '%ZZ'),
        QueryParameter('', 'v'),
      ]);
      expect(parsed('https://e.com/').queryParameters, isEmpty);
      expect(parsed('https://e.com/?').queryParameters, isEmpty);
      expect(
        parsed('https://e.com/?t=%C3%A9%FF').queryParameters.single.value,
        'é\uFFFD',
      );
    });
  });

  group('limites et erreurs', () {
    test('texte vide', () {
      expect(failed('').error, UrlParseError.empty);
      expect(failed(' \n ').error, UrlParseError.empty);
    });

    test('longueur maximale réglable', () {
      final long = 'https://example.com/${'a' * 2028}';
      expect(long.length, 2048);
      expect(_parser.parse(long), isA<ParsedUrl>());
      expect(failed('${long}a').error, UrlParseError.tooLong);
      final small = UrlParser(maxLength: 20);
      expect(small.maxLength, 20);
      expect(
        failed('https://example.com/abc', parser: small).error,
        UrlParseError.tooLong,
      );
      expect(() => UrlParser(maxLength: 0), throwsArgumentError);
    });

    test('ports invalides', () {
      for (final text in [
        'https://example.com:65536/',
        'https://example.com:99999999999/',
        'https://example.com:8a/',
        'https://example.com:-1/',
        'https://[::1]:x/',
      ]) {
        expect(failed(text).error, UrlParseError.invalidPort, reason: text);
      }
      expect(parsed('https://example.com:00000000080/').port, 80);
    });

    test('codes et explications', () {
      for (final error in UrlParseError.values) {
        expect(error.code, matches(RegExp(r'^URL_[A-Z_]+$')));
        expect(error.description, isNotEmpty);
      }
      for (final step in UrlNormalization.values) {
        expect(step.code, matches(RegExp(r'^URL_[A-Z0-9_]+$')));
        expect(step.description, isNotEmpty);
      }
      final codes = {
        ...UrlParseError.values.map((e) => e.code),
        ...UrlNormalization.values.map((e) => e.code),
      };
      expect(
        codes.length,
        UrlParseError.values.length + UrlNormalization.values.length,
      );
    });

    test('affichage sans chemin ni requête', () {
      final url = parsed('https://e.com/secret?token=abc');
      expect(url.toString(), 'ParsedUrl(https://e.com)');
      expect(failed('').toString(), 'UrlParseFailure(URL_EMPTY)');
      expect(url.queryParameters.single.toString(), 'QueryParameter(token)');
      expect(
        url.queryParameters.single,
        isNot(const QueryParameter('token', 'x')),
      );
      expect(
        const QueryParameter('a', 'b').hashCode,
        const QueryParameter('a', 'b').hashCode,
      );
    });

    test('Public Suffix List injectable', () {
      final parser = UrlParser(
        suffixes: PublicSuffixList.fromRules(
          icannRules: 'test',
          privateRules: '',
        ),
      );
      expect(
        (parser.parse('https://a.b.test') as ParsedUrl).registrableDomain,
        'b.test',
      );
      expect(parser.suffixes.length, 1);
      expect(_parser.suffixes, same(PublicSuffixList.embedded));
    });
  });
}
