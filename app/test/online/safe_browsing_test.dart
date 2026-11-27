import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/online/safe_browsing.dart';
import 'package:safelink/features/online/transports.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_google.dart';

ParsedUrl parse(String url) => UrlParser().parse(url) as ParsedUrl;

final now = DateTime.utc(2026, 11, 27);

void main() {
  group('expressions (exemples de la documentation de Google)', () {
    test('a.b.com/1/2.html?param=1 : 8 expressions', () {
      expect(
        SafeBrowsingExpressions.of(parse('http://a.b.com/1/2.html?param=1'))
            .toSet(),
        {
          'a.b.com/1/2.html?param=1',
          'a.b.com/1/2.html',
          'a.b.com/',
          'a.b.com/1/',
          'b.com/1/2.html?param=1',
          'b.com/1/2.html',
          'b.com/',
          'b.com/1/',
        },
      );
    });

    test('a.b.c.d.e.f.com/1.html : 10 expressions, b.c.d.e.f.com sauté', () {
      final expressions = SafeBrowsingExpressions.of(
        parse('http://a.b.c.d.e.f.com/1.html'),
      ).toSet();
      expect(expressions, {
        'a.b.c.d.e.f.com/1.html',
        'a.b.c.d.e.f.com/',
        'c.d.e.f.com/1.html',
        'c.d.e.f.com/',
        'd.e.f.com/1.html',
        'd.e.f.com/',
        'e.f.com/1.html',
        'e.f.com/',
        'f.com/1.html',
        'f.com/',
      });
    });

    test('adresse IP et domaine sous suffixe composé', () {
      expect(SafeBrowsingExpressions.of(parse('http://1.2.3.4/1/')).toSet(), {
        '1.2.3.4/1/',
        '1.2.3.4/',
      });
      expect(
        SafeBrowsingExpressions.of(parse('http://example.co.uk/1')).toSet(),
        {'example.co.uk/1', 'example.co.uk/'},
      );
    });

    test('au plus 4 préfixes de chemin et 30 expressions', () {
      final expressions = SafeBrowsingExpressions.of(
        parse('http://a.b.c.d.e.f.g.com/1/2/3/4/5/6.html?x=1'),
      );
      expect(expressions.length, lessThanOrEqualTo(30));
      final paths = {for (final e in expressions) e.substring(e.indexOf('/'))};
      expect(paths, {
        '/1/2/3/4/5/6.html?x=1',
        '/1/2/3/4/5/6.html',
        '/',
        '/1/',
        '/1/2/',
        '/1/2/3/',
      });
    });

    test('canonicalisation : décodage répété, points, barres, réencodage', () {
      String path(String url) =>
          SafeBrowsingExpressions.canonicalPathAndQuery(parse(url)).$1;
      expect(path('http://host.com/%25%32%35'), '/%25');
      expect(path('http://host.com/a/./b/../c'), '/a/c');
      expect(path('http://host.com//a///b'), '/a/b');
      expect(path('http://host.com/a b'), '/a%20b');
      expect(path('http://host.com/%2e%2e/x'), '/x');
      expect(
        SafeBrowsingExpressions.canonicalHost(parse('http://WWW.Host.com./')),
        'www.host.com',
      );
    });

    test('préfixes de 4 octets, sans doublon', () {
      final prefixes = SafeBrowsingExpressions.prefixes([
        'b.com/',
        'b.com/',
        'a.b.com/1/2.html?param=1',
      ]);
      expect(prefixes, hasLength(2));
      expect(prefixes.first, hasLength(4));
      expect(
        prefixes.map(
          (p) => p.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        ),
        ['650fb6f0', '2fcd902c'],
      );
    });
  });

  group('réponse', () {
    test('JSON', () {
      final matches = SafeBrowsingResponse.parse(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'fullHashes': [
                {
                  'fullHash': 'ZQ+28CXDcwku7Osgxb8HpviLZDQUBHYxk1UZc30+pUw=',
                  'fullHashDetails': [
                    {
                      'threatType': 'SOCIAL_ENGINEERING',
                      'attributes': ['FRAME_ONLY'],
                    },
                  ],
                },
              ],
              'cacheDuration': '300s',
            }),
          ),
        ),
        'application/json',
      );
      expect(matches.single.threatType, 'SOCIAL_ENGINEERING');
      expect(matches.single.attributes, {'FRAME_ONLY'});
      expect(
        matches.single.fullHash,
        base64Encode(SafeBrowsingExpressions.fullHash('b.com/')),
      );
    });

    test('JSON vide : aucune correspondance', () {
      expect(
        SafeBrowsingResponse.parse(
          Uint8List.fromList(utf8.encode('{"cacheDuration":"300s"}')),
          'application/json',
        ),
        isEmpty,
      );
    });

    test('protobuf', () {
      final hash = SafeBrowsingExpressions.fullHash('b.com/');
      // FullHashDetail { threat_type: MALWARE (1), attributes: [CANARY (1)] }
      final detail = [0x08, 0x01, 0x10, 0x01];
      // FullHash { full_hash: 32 octets, full_hash_details: detail }
      final fullHash = [0x0a, 32, ...hash, 0x12, detail.length, ...detail];
      // SearchHashesResponse { full_hashes, cache_duration { seconds: 300 } }
      final body = Uint8List.fromList([
        0x0a, fullHash.length, ...fullHash, //
        0x12, 0x03, 0x08, 0xac, 0x02,
      ]);
      final matches = SafeBrowsingResponse.parse(
        body,
        'application/x-protobuf',
      );
      expect(matches.single.threatType, 'MALWARE');
      expect(matches.single.attributes, {'CANARY'});
      expect(matches.single.fullHash, base64Encode(hash));
    });

    test('protobuf tronqué : refus', () {
      expect(
        () => SafeBrowsingResponse.parse(
          Uint8List.fromList([0x0a, 0x10, 0x01]),
          'application/x-protobuf',
        ),
        throwsFormatException,
      );
    });
  });

  group('client', () {
    test('lien signalé : correspondance et type de menace', () async {
      final client = fakeSafeBrowsing(
        threats: {'secure-login.xyz/': 'SOCIAL_ENGINEERING'},
      );
      final result = await client.check(
        parse('https://www.secure-login.xyz/verify?token=secret'),
        now,
      );
      expect(result.status, ProviderStatus.match);
      expect(result.matches.single.threatType, ThreatType.phishing);
      expect(result.isFreshWithin(Duration.zero), isTrue);

      // Seuls des préfixes partent, avec la clé dans un en-tête.
      final (uri, headers) = (client.http as FakeHttpTransport).requests.single;
      expect(uri.host, 'safebrowsing.googleapis.com');
      expect(uri.path, '/v5/hashes:search');
      expect(uri.toString(), isNot(contains('secure-login')));
      expect(uri.toString(), isNot(contains('secret')));
      expect(uri.toString(), isNot(contains('test-key')));
      expect(headers['X-Goog-Api-Key'], 'test-key');
      expect(uri.queryParametersAll['hashPrefixes'], isNotEmpty);
    });

    test('empreinte voisine d’une autre page : ignorée', () async {
      final client = fakeSafeBrowsing(threats: {'autre-site.com/': 'MALWARE'});
      final result = await client.check(parse('https://exemple.com/'), now);
      expect(result.status, ProviderStatus.noMatch);
    });

    test('CANARY et FRAME_ONLY ne déclenchent pas d’alerte', () async {
      final client = SafeBrowsingClient(
        apiKey: 'k',
        http: FakeHttpTransport(
          (_) => jsonReply({
            'fullHashes': [
              {
                'fullHash': base64Encode(
                  SafeBrowsingExpressions.fullHash('exemple.com/'),
                ),
                'fullHashDetails': [
                  {
                    'threatType': 'MALWARE',
                    'attributes': ['CANARY'],
                  },
                  {
                    'threatType': 'SOCIAL_ENGINEERING',
                    'attributes': ['FRAME_ONLY'],
                  },
                ],
              },
            ],
          }),
        ),
      );
      final result = await client.check(parse('https://exemple.com/'), now);
      expect(result.status, ProviderStatus.noMatch);
    });

    test('erreur HTTP, panne, réponse illisible', () async {
      final refused = SafeBrowsingClient(
        apiKey: 'k',
        http: FakeHttpTransport((_) => jsonReply({}, status: 403)),
      );
      final error = await refused.check(parse('https://exemple.com/'), now);
      expect(error.status, ProviderStatus.error);
      expect(error.errorCode, 'HTTP_403');

      final offline = await fakeSafeBrowsing(offline: true)
          .check(parse('https://exemple.com/'), now);
      expect(offline.status, ProviderStatus.unavailable);

      final garbled = SafeBrowsingClient(
        apiKey: 'k',
        http: FakeHttpTransport(
          (_) => HttpReply(200, 'application/json', Uint8List.fromList([1])),
        ),
      );
      expect(
        (await garbled.check(parse('https://exemple.com/'), now)).errorCode,
        'BAD_RESPONSE',
      );
    });

    test('réponse gardée 5 minutes', () async {
      final client = fakeSafeBrowsing();
      final url = parse('https://exemple.com/');
      await client.check(url, now);
      await client.check(url, now.add(const Duration(minutes: 4)));
      final http = client.http as FakeHttpTransport;
      expect(http.requests, hasLength(1));
      await client.check(url, now.add(const Duration(minutes: 6)));
      expect(http.requests, hasLength(2));
    });
  });
}
