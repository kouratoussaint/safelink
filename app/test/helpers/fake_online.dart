import 'dart:typed_data';

import 'package:safelink/features/online/dns_message.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/transports.dart';

/// Réponse DNS binaire construite pour les tests.
Uint8List dnsAnswer({
  int rcode = 0,
  List<String> addresses = const ['93.184.215.14'],
  int authorities = 0,
  int? extendedError,
}) {
  final bytes = BytesBuilder()
    ..add([0, 0, 0x81, 0x80 | rcode])
    ..add([0, 1, 0, addresses.length, 0, authorities])
    ..add([0, if (extendedError == null) 0 else 1])
    // Question : « a.example », type A, classe IN.
    ..add([1, 0x61, 7, ...'example'.codeUnits, 0, 0, 1, 0, 1]);
  for (final address in addresses) {
    bytes
      ..add([0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4])
      ..add(address.split('.').map(int.parse).toList());
  }
  for (var i = 0; i < authorities; i++) {
    // SOA réduit à des octets quelconques.
    bytes.add([0xc0, 0x0c, 0, 6, 0, 1, 0, 0, 0, 60, 0, 2, 0, 0]);
  }
  final error = extendedError;
  if (error != null) {
    bytes.add([
      0, 0, DnsMessage.typeOpt, 0x04, 0xd0, 0, 0, 0, 0, //
      0, 6, 0, DnsMessage.optionExtendedError, 0, 2, error >> 8, error & 0xff,
    ]);
  }
  return bytes.toBytes();
}

/// Résolveurs simulés : noms bloqués par source, noms inexistants, panne.
final class FakeDohTransport implements DohTransport {
  new({
    this.blockedByQuad9 = const {},
    this.blockedByCloudflare = const {},
    this.missing = const {},
    this.offline = false,
  });

  final Set<String> blockedByQuad9;
  final Set<String> blockedByCloudflare;
  final Set<String> missing;
  final bool offline;

  /// Noms reçus, pour vérifier ce qui a été envoyé.
  final sentNames = <String>[];
  final endpoints = <String>[];

  static String nameOf(Uint8List query) {
    final labels = <String>[];
    var offset = 12;
    while (query[offset] != 0) {
      final length = query[offset];
      labels.add(String.fromCharCodes(query, offset + 1, offset + 1 + length));
      offset += 1 + length;
    }
    return labels.join('.');
  }

  @override
  Future<Uint8List> send(Uri endpoint, Uint8List message) async {
    if (offline) throw const OnlineLookupException('UNREACHABLE');
    final name = nameOf(message);
    sentNames.add(name);
    endpoints.add(endpoint.host);
    final source = endpoint.toString();
    if (source == ReputationSource.quad9.endpoint &&
        blockedByQuad9.contains(name)) {
      return dnsAnswer(rcode: 3, addresses: const [], extendedError: 17);
    }
    if (source == ReputationSource.cloudflare.endpoint &&
        blockedByCloudflare.contains(name)) {
      return dnsAnswer(addresses: const ['0.0.0.0'], extendedError: 16);
    }
    if (missing.contains(name)) {
      return dnsAnswer(rcode: 3, addresses: const [], authorities: 1);
    }
    return dnsAnswer();
  }
}

/// Serveurs RDAP simulés : date de création par domaine.
final class FakeJsonTransport implements JsonTransport {
  new({this.registeredOn = const {}, this.offline = false});

  final Map<String, DateTime> registeredOn;
  final bool offline;
  final requested = <Uri>[];

  @override
  Future<Map<String, Object?>?> get(Uri uri) async {
    if (offline) throw const OnlineLookupException('UNREACHABLE');
    requested.add(uri);
    final domain = uri.pathSegments.last;
    final date = registeredOn[domain];
    if (date == null) return null;
    return {
      'objectClassName': 'domain',
      'events': [
        {'eventAction': 'expiration', 'eventDate': '2030-01-01T00:00:00Z'},
        {
          'eventAction': 'registration',
          'eventDate': date.toUtc().toIso8601String(),
        },
      ],
    };
  }
}

/// Vérificateur entièrement simulé.
OnlineChecker fakeChecker({
  FakeDohTransport? dns,
  FakeJsonTransport? json,
  DateTime Function()? clock,
}) => OnlineChecker(
  dns: dns ?? FakeDohTransport(),
  json: json ?? FakeJsonTransport(),
  clock: clock,
);

/// Vérificateur sans connexion.
OnlineChecker offlineChecker() => OnlineChecker(
  dns: FakeDohTransport(offline: true),
  json: FakeJsonTransport(offline: true),
);
