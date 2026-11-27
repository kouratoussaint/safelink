import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http2/http2.dart';

/// Erreur d'une consultation en ligne, sans détail personnel.
final class OnlineLookupException implements Exception {
  /// Crée l'erreur ; [code] est stable (`TIMEOUT`, `UNREACHABLE`…).
  const new(this.code);

  /// Code stable.
  final String code;

  @override
  String toString() => 'OnlineLookupException($code)';
}

/// Envoie une requête DNS binaire à un serveur DNS sur HTTPS (RFC 8484).
abstract interface class DohTransport {
  /// Envoie [message] à [endpoint] et renvoie la réponse binaire.
  Future<Uint8List> send(Uri endpoint, Uint8List message);
}

/// Lit un document JSON sur HTTPS.
abstract interface class JsonTransport {
  /// Document à [uri], ou `null` si le serveur répond 404.
  Future<Map<String, Object?>?> get(Uri uri);
}

/// Réponse HTTP brute.
final class HttpReply {
  /// Crée une réponse.
  const new(this.statusCode, this.contentType, this.body, {this.location});

  /// Code HTTP.
  final int statusCode;

  /// En-tête `Location` d'une redirection, s'il y en a un.
  final String? location;

  /// Type de contenu (`application/json`…), en minuscules.
  final String contentType;

  /// Corps de la réponse.
  final Uint8List body;
}

/// Requête HTTP GET générique sur HTTPS.
abstract interface class HttpTransport {
  /// Envoie un GET à [uri] avec [headers].
  Future<HttpReply> get(Uri uri, {Map<String, String> headers = const {}});
}

/// Taille maximale acceptée pour une réponse.
const int _maxResponseBytes = 256 * 1024;

/// DNS sur HTTPS en HTTP/2, exigé par Quad9 et accepté par Cloudflare.
///
/// Une connexion TLS est ouverte par requête : aucun cookie, aucun
/// identifiant n'est conservé d'une consultation à l'autre.
final class Http2DohTransport implements DohTransport {
  /// Crée le transport ; [timeout] borne chaque requête. [connect] ouvre la
  /// connexion TLS (remplaçable pour les essais à travers un mandataire).
  const new({
    this.timeout = const Duration(seconds: 6),
    this.connect = _connect,
  });

  /// Délai maximal d'une requête.
  final Duration timeout;

  /// Ouvre une connexion TLS négociant HTTP/2.
  final Future<SecureSocket> Function(String host, int port, Duration timeout)
  connect;

  static Future<SecureSocket> _connect(
    String host,
    int port,
    Duration timeout,
  ) => SecureSocket.connect(
    host,
    port,
    supportedProtocols: const ['h2'],
    timeout: timeout,
  );

  @override
  Future<Uint8List> send(Uri endpoint, Uint8List message) =>
      _send(endpoint, message).timeout(
        timeout,
        onTimeout: () => throw const OnlineLookupException('TIMEOUT'),
      );

  Future<Uint8List> _send(Uri endpoint, Uint8List message) async {
    SecureSocket socket;
    try {
      socket = await connect(
        endpoint.host,
        endpoint.hasPort ? endpoint.port : 443,
        timeout,
      );
    } on SocketException {
      throw const OnlineLookupException('UNREACHABLE');
    } on HandshakeException {
      throw const OnlineLookupException('TLS');
    }
    final connection = ClientTransportConnection.viaSocket(socket);
    try {
      final stream = connection.makeRequest([
        Header.ascii(':method', 'POST'),
        Header.ascii(':scheme', 'https'),
        Header.ascii(':path', endpoint.path),
        Header.ascii(':authority', endpoint.host),
        Header.ascii('content-type', 'application/dns-message'),
        Header.ascii('accept', 'application/dns-message'),
        Header.ascii('content-length', '${message.length}'),
      ])..sendData(message, endStream: true);
      var status = '';
      final body = BytesBuilder(copy: false);
      await for (final part in stream.incomingMessages) {
        if (part is HeadersStreamMessage) {
          for (final header in part.headers) {
            if (ascii.decode(header.name) == ':status') {
              status = ascii.decode(header.value);
            }
          }
        } else if (part is DataStreamMessage) {
          body.add(part.bytes);
          if (body.length > _maxResponseBytes) {
            throw const OnlineLookupException('TOO_LARGE');
          }
        }
      }
      if (status != '200') throw OnlineLookupException('HTTP_$status');
      return body.toBytes();
    } on TransportException {
      throw const OnlineLookupException('UNREACHABLE');
    } finally {
      unawaited(connection.finish().catchError((Object _) {}));
      socket.destroy();
    }
  }
}

/// Lecture JSON sur HTTPS avec `dart:io`, pour les serveurs RDAP.
final class IoJsonTransport implements JsonTransport {
  /// Crée le transport ; [timeout] borne chaque requête.
  const new({this.timeout = const Duration(seconds: 6)});

  /// Délai maximal d'une requête.
  final Duration timeout;

  @override
  Future<Map<String, Object?>?> get(Uri uri) => _get(uri).timeout(
    timeout,
    onTimeout: () => throw const OnlineLookupException('TIMEOUT'),
  );

  Future<Map<String, Object?>?> _get(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const OnlineLookupException('INSECURE');
    }
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'SafeLink'
      ..autoUncompress = true;
    try {
      final request = await client.getUrl(uri);
      request
        ..followRedirects = true
        ..maxRedirects = 3
        ..headers.set(HttpHeaders.acceptHeader, 'application/rdap+json');
      final response = await request.close();
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw OnlineLookupException('HTTP_${response.statusCode}');
      }
      final body = BytesBuilder(copy: false);
      await for (final chunk in response) {
        body.add(chunk);
        if (body.length > _maxResponseBytes) {
          throw const OnlineLookupException('TOO_LARGE');
        }
      }
      final decoded = jsonDecode(utf8.decode(body.toBytes()));
      if (decoded is! Map<String, Object?>) {
        throw const OnlineLookupException('BAD_RESPONSE');
      }
      return decoded;
    } on SocketException {
      throw const OnlineLookupException('UNREACHABLE');
    } on HandshakeException {
      throw const OnlineLookupException('TLS');
    } on HttpException {
      throw const OnlineLookupException('UNREACHABLE');
    } on FormatException {
      throw const OnlineLookupException('BAD_RESPONSE');
    } finally {
      client.close(force: true);
    }
  }
}

/// GET sur HTTPS avec `dart:io`, réponse bornée en taille et en temps.
final class IoHttpTransport implements HttpTransport {
  /// Crée le transport.
  const new({
    this.timeout = const Duration(seconds: 8),
    this.maxBytes = _maxResponseBytes,
  });

  /// Délai maximal d'une requête.
  final Duration timeout;

  /// Taille maximale de la réponse.
  final int maxBytes;

  @override
  Future<HttpReply> get(Uri uri, {Map<String, String> headers = const {}}) =>
      _get(uri, headers).timeout(
        timeout,
        onTimeout: () => throw const OnlineLookupException('TIMEOUT'),
      );

  Future<HttpReply> _get(Uri uri, Map<String, String> headers) async {
    if (uri.scheme != 'https') {
      throw const OnlineLookupException('INSECURE');
    }
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'SafeLink'
      ..autoUncompress = true;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = BytesBuilder(copy: false);
      await for (final chunk in response) {
        body.add(chunk);
        if (body.length > maxBytes) {
          throw const OnlineLookupException('TOO_LARGE');
        }
      }
      return HttpReply(
        response.statusCode,
        response.headers.contentType?.mimeType.toLowerCase() ?? '',
        body.toBytes(),
        location: response.headers.value(HttpHeaders.locationHeader),
      );
    } on SocketException {
      throw const OnlineLookupException('UNREACHABLE');
    } on HandshakeException {
      throw const OnlineLookupException('TLS');
    } on HttpException {
      throw const OnlineLookupException('UNREACHABLE');
    } finally {
      client.close(force: true);
    }
  }
}
