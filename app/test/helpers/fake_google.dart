import 'dart:convert';
import 'dart:typed_data';

import 'package:safelink/features/online/page_preview.dart';
import 'package:safelink/features/online/safe_browsing.dart';
import 'package:safelink/features/online/transports.dart';

/// Image PNG de 1 × 1 pixel, pour les aperçus simulés.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
  '/pLvAAAAAElFTkSuQmCC',
);

/// Transport HTTP simulé : répond selon une fonction, garde les requêtes.
final class FakeHttpTransport implements HttpTransport {
  new(this.respond);

  final HttpReply Function(Uri uri) respond;
  final requests = <(Uri, Map<String, String>)>[];

  @override
  Future<HttpReply> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add((uri, headers));
    return respond(uri);
  }
}

HttpReply jsonReply(Object body, {int status = 200}) => HttpReply(
  status,
  'application/json',
  Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

/// Safe Browsing simulé : signale les expressions données.
SafeBrowsingClient fakeSafeBrowsing({
  Map<String, String> threats = const {},
  bool offline = false,
}) => SafeBrowsingClient(
  apiKey: 'test-key',
  http: FakeHttpTransport((uri) {
    if (offline) throw const OnlineLookupException('UNREACHABLE');
    return jsonReply({
      'fullHashes': [
        for (final MapEntry(key: expression, value: type) in threats.entries)
          {
            'fullHash': base64Encode(
              SafeBrowsingExpressions.fullHash(expression),
            ),
            'fullHashDetails': [
              {'threatType': type},
            ],
          },
      ],
      'cacheDuration': '300s',
    });
  }),
);

/// Aperçus simulés : capture, page injoignable, ou redirection.
PagePreviewClient fakePreview({String? finalUrl, bool unreachable = false}) =>
    PagePreviewClient(
      apiKey: 'test-key',
      http: FakeHttpTransport((uri) {
        if (unreachable) {
          return jsonReply({
            'error': {
              'code': 500,
              'message': 'Lighthouse returned error: FAILED_DOCUMENT_REQUEST.',
            },
          }, status: 500);
        }
        return jsonReply({
          'lighthouseResult': {
            'finalDisplayedUrl': finalUrl ?? uri.queryParameters['url'],
            'audits': {
              'final-screenshot': {
                'details': {
                  'data': 'data:image/png;base64,${base64Encode(tinyPng)}',
                },
              },
            },
          },
        });
      }),
    );
