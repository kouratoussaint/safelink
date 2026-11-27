import 'dart:typed_data';

import 'package:safelink/features/online/short_links.dart';
import 'package:safelink/features/online/transports.dart';

import 'fake_google.dart';

/// Raccourcisseurs simulés : [redirects] associe un lien (en HTTPS) à
/// l'adresse donnée dans `Location`. Lien inconnu : 404.
ShortLinkResolver fakeShortLinks(
  Map<String, String> redirects, {
  bool offline = false,
}) => ShortLinkResolver(
  http: FakeHttpTransport((uri) {
    if (offline) throw const OnlineLookupException('UNREACHABLE');
    final target = redirects[uri.toString()];
    return target == null
        ? HttpReply(404, 'text/html', Uint8List(0))
        : HttpReply(301, 'text/html', Uint8List(0), location: target);
  }),
);
