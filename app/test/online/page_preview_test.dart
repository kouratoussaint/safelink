import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/online/page_preview.dart';
import 'package:safelink/features/online/transports.dart';

import '../helpers/fake_google.dart';

void main() {
  test('capture : image, adresse finale, requête limitée', () async {
    final client = fakePreview(finalUrl: 'https://destination.example/');
    final preview = await client.capture('https://bit.ly/abc');
    expect(preview.screenshot, tinyPng);
    expect(preview.finalUrl, 'https://destination.example/');

    final (uri, headers) = (client.http as FakeHttpTransport).requests.single;
    expect(uri.host, 'www.googleapis.com');
    expect(uri.path, '/pagespeedonline/v5/runPagespeed');
    expect(uri.queryParameters['url'], 'https://bit.ly/abc');
    expect(uri.queryParameters['strategy'], 'mobile');
    expect(uri.queryParameters['fields'], PagePreviewClient.fields);
    expect(uri.queryParameters, isNot(contains('key')));
    expect(headers['X-Goog-Api-Key'], 'test-key');

    // Même lien : pas de nouvelle requête.
    await client.capture('https://bit.ly/abc');
    expect((client.http as FakeHttpTransport).requests, hasLength(1));
  });

  test('page injoignable', () async {
    await expectLater(
      fakePreview(unreachable: true).capture('https://ferme.example/'),
      throwsA(
        isA<PagePreviewException>().having(
          (e) => e.code,
          'code',
          'PAGE_UNREACHABLE',
        ),
      ),
    );
    expect(
      () => PagePreviewClient.parse(
        jsonReply({
          'lighthouseResult': {
            'runtimeError': {'code': 'NO_FCP'},
          },
        }),
      ),
      throwsA(isA<PagePreviewException>()),
    );
  });

  test('quota épuisé, réponse illisible, panne', () async {
    String codeOf(HttpReply reply) {
      try {
        PagePreviewClient.parse(reply);
      } on PagePreviewException catch (e) {
        return e.code;
      }
      return 'OK';
    }

    expect(codeOf(jsonReply({}, status: 429)), 'QUOTA');
    expect(
      codeOf(HttpReply(200, 'text/html', Uint8List.fromList(utf8.encode('<')))),
      'UNAVAILABLE',
    );
    expect(
      codeOf(jsonReply({'lighthouseResult': <String, Object?>{}})),
      'PAGE_UNREACHABLE',
    );
    expect(codeOf(jsonReply({}, status: 403)), 'UNAVAILABLE');

    final offline = PagePreviewClient(
      apiKey: 'k',
      http: FakeHttpTransport(
        (_) => throw const OnlineLookupException('UNREACHABLE'),
      ),
    );
    await expectLater(
      offline.capture('https://exemple.com/'),
      throwsA(isA<PagePreviewException>()),
    );
  });
}
