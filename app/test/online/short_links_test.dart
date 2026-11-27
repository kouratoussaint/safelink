import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/online/short_links.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_google.dart';
import '../helpers/fake_short_links.dart';

ParsedUrl parse(String url) => UrlParser().parse(url) as ParsedUrl;

List<String> hosts(ShortLinkResolver resolver) => [
  for (final (uri, _) in (resolver.http as FakeHttpTransport).requests)
    uri.host,
];

void main() {
  test('lien raccourci : destination lue, jamais contactée', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/abc': 'https://faux-orange.xyz/login',
    });
    final destination = await resolver.resolve(parse('https://bit.ly/abc'));
    expect(destination?.href, 'https://faux-orange.xyz/login');
    expect(hosts(resolver), ['bit.ly']);
  });

  test('raccourcisseurs enchaînés, adresse relative', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/abc': 'https://tinyurl.com/xyz',
      'https://tinyurl.com/xyz': '/final',
    });
    // « /final » reste sur tinyurl.com : encore un raccourcisseur, qui ne
    // redirige plus ; la dernière adresse connue est rendue.
    final destination = await resolver.resolve(parse('https://bit.ly/abc'));
    expect(destination?.href, 'https://tinyurl.com/final');
    expect(hosts(resolver), ['bit.ly', 'tinyurl.com', 'tinyurl.com']);
  });

  test('lien en http : interrogé en https', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/abc': 'http://site-mort.com/',
    });
    final destination = await resolver.resolve(parse('http://bit.ly/abc'));
    expect(destination?.href, 'http://site-mort.com/');
    final (uri, _) = (resolver.http as FakeHttpTransport).requests.single;
    expect(uri.scheme, 'https');
  });

  test('avertissement de Bitly : destination prise dans l’adresse', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/abc':
          'https://bitly.com/a/warning?hash=abc&url=https%3A%2F%2Fpiege.xyz%2F',
    });
    final destination = await resolver.resolve(parse('https://bit.ly/abc'));
    expect(destination?.href, 'https://piege.xyz/');
    expect(hosts(resolver), ['bit.ly']);
  });

  test('pas un lien raccourci : aucune requête', () async {
    final resolver = fakeShortLinks({});
    expect(await resolver.resolve(parse('https://lefaso.net/')), isNull);
    expect(hosts(resolver), isEmpty);
  });

  test('service muet ou injoignable : destination inconnue', () async {
    expect(
      await fakeShortLinks({}).resolve(parse('https://bit.ly/inconnu')),
      isNull,
    );
    expect(
      await fakeShortLinks(
        {},
        offline: true,
      ).resolve(parse('https://bit.ly/abc')),
      isNull,
    );
  });

  test('boucle de raccourcisseurs : arrêt après 5 sauts', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/a': 'https://bit.ly/b',
      'https://bit.ly/b': 'https://bit.ly/a',
    });
    await resolver.resolve(parse('https://bit.ly/a'));
    expect(hosts(resolver), hasLength(ShortLinkResolver.maxHops));
  });

  test('même lien : réponse gardée en mémoire', () async {
    final resolver = fakeShortLinks({
      'https://bit.ly/abc': 'https://exemple.com/',
    });
    await resolver.resolve(parse('https://bit.ly/abc'));
    await resolver.resolve(parse('https://bit.ly/abc'));
    expect(hosts(resolver), hasLength(1));
  });
}
