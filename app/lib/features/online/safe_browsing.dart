import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:safelink/features/online/transports.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Expressions « hôte/chemin » d'une adresse, selon les règles de
/// Google Safe Browsing (canonicalisation, suffixes d'hôte, préfixes de
/// chemin), et leurs empreintes SHA-256.
///
/// Seuls les 4 premiers octets de chaque empreinte sont envoyés à Google :
/// le lien lui-même ne quitte pas le téléphone.
abstract final class SafeBrowsingExpressions {
  /// Expressions de [url], 30 au plus, sans doublon.
  static List<String> of(ParsedUrl url) {
    final host = canonicalHost(url);
    final (path, query) = canonicalPathAndQuery(url);
    final hosts = <String>{host};
    if (url.hostType == UrlHostType.domain) {
      final labels = host.split('.');
      final registrable = url.registrableDomain;
      final start = registrable == null
          ? (labels.length >= 2 ? 2 : labels.length)
          : registrable.split('.').length;
      // Jusqu'à quatre noms, du domaine enregistré vers le nom complet,
      // pris parmi les cinq derniers composants.
      final suffixes = <String>[];
      for (var count = start; count < labels.length && count <= 5; count++) {
        suffixes.add(labels.sublist(labels.length - count).join('.'));
      }
      hosts.addAll(suffixes.take(4));
    }
    final paths = <String>{if (query != null) '$path?$query', path, '/'};
    final segments = path.split('/');
    // Préfixes « / », « /a/ », « /a/b/ », « /a/b/c/ » : quatre au plus (le
    // dernier segment est un fichier ou vide).
    final prefix = StringBuffer('/');
    var prefixCount = 1;
    for (var i = 1; i < segments.length - 1 && prefixCount < 4; i++) {
      if (segments[i].isEmpty) continue;
      prefix
        ..write(segments[i])
        ..write('/');
      paths.add(prefix.toString());
      prefixCount++;
    }
    return [
      for (final h in hosts)
        for (final p in paths) '$h$p',
    ].take(30).toList();
  }

  /// Empreinte SHA-256 complète d'une expression.
  static Uint8List fullHash(String expression) =>
      Uint8List.fromList(sha256.convert(ascii.encode(expression)).bytes);

  /// Préfixes de 4 octets à envoyer, sans doublon.
  static List<Uint8List> prefixes(Iterable<String> expressions) {
    final seen = <String>{};
    return [
      for (final expression in expressions)
        if (seen.add(base64Encode(fullHash(expression).sublist(0, 4))))
          fullHash(expression).sublist(0, 4),
    ];
  }

  /// Nom d'hôte canonique : sans points en tête, en fin ou répétés.
  static String canonicalHost(ParsedUrl url) {
    if (url.hostType != UrlHostType.domain) return url.host.toLowerCase();
    return url.host
        .toLowerCase()
        .split('.')
        .where((label) => label.isNotEmpty)
        .join('.');
  }

  /// Chemin et requête canoniques : décodés jusqu'au bout, segments `.` et
  /// `..` résolus, barres répétées réduites, puis réencodés.
  static (String, String?) canonicalPathAndQuery(ParsedUrl url) {
    final decodedPath = _unescapeFully(url.path);
    final segments = <String>[];
    final parts = decodedPath.split('/');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final last = i == parts.length - 1;
      if (part == '.') {
        if (last) segments.add('');
        continue;
      }
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        if (last) segments.add('');
        continue;
      }
      if (part.isEmpty && !last) continue;
      segments.add(part);
    }
    var path = '/${segments.join('/')}';
    path = path.replaceAll(RegExp('/{2,}'), '/');
    final query = url.query;
    return (
      _escape(path),
      query == null ? null : _escape(_unescapeFully(query)),
    );
  }

  /// Décode les `%XX` jusqu'à ce qu'il n'en reste plus (octets en Latin-1).
  static String _unescapeFully(String input) {
    var current = input;
    for (var round = 0; round < 1024; round++) {
      final next = _unescapeOnce(current);
      if (next == current) return current;
      current = next;
    }
    return current;
  }

  static final _escapeSequence = RegExp('%([0-9A-Fa-f]{2})');

  static String _unescapeOnce(String input) => input.replaceAllMapped(
    _escapeSequence,
    (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
  );

  /// Encode les octets ≤ 32, ≥ 127, `#` et `%` (hexadécimal majuscule).
  static String _escape(String input) {
    final buffer = StringBuffer();
    // Les caractères au-delà d'un octet sont d'abord écrits en UTF-8.
    final bytes = input.codeUnits.every((c) => c < 256)
        ? input.codeUnits
        : utf8.encode(input);
    for (final byte in bytes) {
      if (byte <= 32 || byte >= 127 || byte == 0x23 || byte == 0x25) {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      } else {
        buffer.writeCharCode(byte);
      }
    }
    return buffer.toString();
  }
}

/// Correspondance renvoyée par Google pour une empreinte complète.
final class SafeBrowsingMatch {
  /// Crée une correspondance.
  const new(this.fullHash, this.threatType, this.attributes);

  /// Empreinte complète (32 octets), en base64.
  final String fullHash;

  /// Type de menace : `MALWARE`, `SOCIAL_ENGINEERING`…
  final String threatType;

  /// Attributs : `CANARY`, `FRAME_ONLY`.
  final Set<String> attributes;
}

/// Lecture de la réponse de `hashes:search`, en JSON ou en protobuf.
abstract final class SafeBrowsingResponse {
  static const _threatTypes = {
    1: 'MALWARE',
    2: 'SOCIAL_ENGINEERING',
    3: 'UNWANTED_SOFTWARE',
    4: 'POTENTIALLY_HARMFUL_APPLICATION',
  };
  static const _attributes = {1: 'CANARY', 2: 'FRAME_ONLY'};

  /// Correspondances de [body] ; lève [FormatException] si illisible.
  static List<SafeBrowsingMatch> parse(Uint8List body, String contentType) {
    if (contentType.contains('json')) return _json(body);
    if (body.isNotEmpty && body.first == 0x7b) return _json(body); // « { »
    return _protobuf(body);
  }

  static List<SafeBrowsingMatch> _json(Uint8List body) {
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map) throw const FormatException('Réponse inattendue.');
    final hashes = decoded['fullHashes'];
    if (hashes == null) return const [];
    if (hashes is! List) throw const FormatException('fullHashes invalide.');
    return [
      for (final hash in hashes)
        if (hash is Map && hash['fullHash'] is String)
          for (final detail in (hash['fullHashDetails'] as List?) ?? const [])
            if (detail is Map)
              SafeBrowsingMatch(
                base64Encode(base64Decode(_pad(hash['fullHash'] as String))),
                '${detail['threatType'] ?? 'THREAT_TYPE_UNSPECIFIED'}',
                {
                  for (final a in (detail['attributes'] as List?) ?? const [])
                    '$a',
                },
              ),
    ];
  }

  static String _pad(String value) {
    final normal = value.replaceAll('-', '+').replaceAll('_', '/');
    return normal.padRight((normal.length + 3) ~/ 4 * 4, '=');
  }

  static List<SafeBrowsingMatch> _protobuf(Uint8List body) {
    final matches = <SafeBrowsingMatch>[];
    for (final (field, value) in _Proto(body).fields()) {
      if (field != 1 || value is! Uint8List) continue;
      Uint8List? hash;
      final details = <(String, Set<String>)>[];
      for (final (f, v) in _Proto(value).fields()) {
        if (f == 1 && v is Uint8List) hash = v;
        if (f == 2 && v is Uint8List) {
          var type = 'THREAT_TYPE_UNSPECIFIED';
          final attributes = <String>{};
          for (final (df, dv) in _Proto(v).fields()) {
            if (df == 1 && dv is int) type = _threatTypes[dv] ?? type;
            if (df == 2 && dv is int) attributes.add(_attributes[dv] ?? '$dv');
            if (df == 2 && dv is Uint8List) {
              // Énumérations répétées « packed ».
              for (final a in _Proto(dv).varints()) {
                attributes.add(_attributes[a] ?? '$a');
              }
            }
          }
          details.add((type, attributes));
        }
      }
      if (hash == null) continue;
      for (final (type, attributes) in details) {
        matches.add(SafeBrowsingMatch(base64Encode(hash), type, attributes));
      }
    }
    return matches;
  }
}

/// Lecteur protobuf minimal (varints et champs délimités).
final class _Proto {
  new(this._data);

  final Uint8List _data;
  int _offset = 0;

  int _varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _data.length || shift > 63) {
        throw const FormatException('Varint tronqué.');
      }
      final byte = _data[_offset++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
    }
  }

  Iterable<int> varints() sync* {
    while (_offset < _data.length) {
      yield _varint();
    }
  }

  Iterable<(int, Object)> fields() sync* {
    while (_offset < _data.length) {
      final key = _varint();
      final field = key >> 3;
      switch (key & 7) {
        case 0:
          yield (field, _varint());
        case 1:
          _skip(8);
        case 2:
          final length = _varint();
          if (length < 0 || _offset + length > _data.length) {
            throw const FormatException('Champ tronqué.');
          }
          yield (
            field,
            Uint8List.sublistView(_data, _offset, _offset + length),
          );
          _offset += length;
        case 5:
          _skip(4);
        default:
          throw const FormatException('Type de champ inconnu.');
      }
    }
  }

  void _skip(int count) {
    if (_offset + count > _data.length) {
      throw const FormatException('Champ tronqué.');
    }
    _offset += count;
  }
}

/// Client de Google Safe Browsing v5 (`hashes:search`).
final class SafeBrowsingClient {
  /// Crée le client avec la clé d'API du projet.
  new({required this.apiKey, this.http = const IoHttpTransport()});

  /// Identifiant de la source dans les résultats.
  static const providerId = 'GOOGLE_SAFE_BROWSING';

  /// Clé d'API Google.
  final String apiKey;

  /// Transport HTTP.
  final HttpTransport http;

  final _cache = <String, (DateTime, ProviderResult)>{};

  /// Consulte Google pour [url] ; ne lève jamais d'exception.
  Future<ProviderResult> check(ParsedUrl url, DateTime checkedAt) async {
    final expressions = SafeBrowsingExpressions.of(url);
    final key = expressions.join(' ');
    final cached = _cache[key];
    if (cached != null && cached.$1.isAfter(checkedAt)) return cached.$2;

    final prefixes = SafeBrowsingExpressions.prefixes(expressions);
    // Réponse en protobuf : `hashes:search` refuse `$alt=json`
    // (« Unsupported Output Format », vérifié le 27/11/2026).
    final uri = Uri.https('safebrowsing.googleapis.com', '/v5/hashes:search', {
      'hashPrefixes': [for (final p in prefixes) base64Encode(p)],
    });
    try {
      final reply = await http.get(uri, headers: {'X-Goog-Api-Key': apiKey});
      if (reply.statusCode != 200) {
        return ProviderResult(
          providerId: providerId,
          status: ProviderStatus.error,
          checkedAt: checkedAt,
          errorCode: 'HTTP_${reply.statusCode}',
        );
      }
      final ours = {
        for (final e in expressions)
          base64Encode(SafeBrowsingExpressions.fullHash(e)),
      };
      final threats = <ThreatType>{};
      for (final match in SafeBrowsingResponse.parse(
        reply.body,
        reply.contentType,
      )) {
        if (!ours.contains(match.fullHash)) continue;
        // « CANARY » : ne doit pas déclencher d'alerte ; « FRAME_ONLY » :
        // ne concerne que les pages chargées dans un cadre.
        if (match.attributes.contains('CANARY') ||
            match.attributes.contains('FRAME_ONLY')) {
          continue;
        }
        threats.add(switch (match.threatType) {
          'SOCIAL_ENGINEERING' => ThreatType.phishing,
          'MALWARE' || 'POTENTIALLY_HARMFUL_APPLICATION' => ThreatType.malware,
          _ => ThreatType.other,
        });
      }
      final result = threats.isEmpty
          ? ProviderResult(
              providerId: providerId,
              status: ProviderStatus.noMatch,
              checkedAt: checkedAt,
              feedUpdatedAt: checkedAt,
            )
          : ProviderResult(
              providerId: providerId,
              status: ProviderStatus.match,
              checkedAt: checkedAt,
              feedUpdatedAt: checkedAt,
              matches: [for (final t in threats) ThreatMatch(threatType: t)],
            );
      _cache[key] = (checkedAt.add(const Duration(minutes: 5)), result);
      return result;
    } on OnlineLookupException {
      return ProviderResult(
        providerId: providerId,
        status: ProviderStatus.unavailable,
        checkedAt: checkedAt,
      );
    } on FormatException {
      return ProviderResult(
        providerId: providerId,
        status: ProviderStatus.error,
        checkedAt: checkedAt,
        errorCode: 'BAD_RESPONSE',
      );
    }
  }
}
