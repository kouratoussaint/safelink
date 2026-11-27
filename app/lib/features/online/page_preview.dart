import 'dart:convert';
import 'dart:typed_data';

import 'package:safelink/features/online/transports.dart';

/// Photo d'une page, prise par les serveurs de Google : le téléphone ne
/// contacte jamais le site.
final class PagePreview {
  /// Crée un aperçu.
  const new({required this.screenshot, required this.finalUrl});

  /// Image JPEG de la page telle qu'elle s'affiche sur un téléphone.
  final Uint8List screenshot;

  /// Adresse finale après les redirections, si Google l'indique.
  final String? finalUrl;
}

/// Échec de l'aperçu, avec un code stable.
final class PagePreviewException implements Exception {
  /// Crée l'erreur.
  const new(this.code);

  /// `PAGE_UNREACHABLE` (la page ne s'affiche pas), `QUOTA`, `UNAVAILABLE`.
  final String code;

  @override
  String toString() => 'PagePreviewException($code)';
}

/// Aperçu des pages par l'API PageSpeed Insights de Google : un navigateur
/// de Google charge la page et en renvoie une capture.
final class PagePreviewClient {
  /// Crée le client avec la clé d'API du projet.
  new({
    required this.apiKey,
    this.http = const IoHttpTransport(
      // Google met jusqu'à une minute pour certaines pages.
      timeout: Duration(seconds: 120),
      maxBytes: 8 * 1024 * 1024,
    ),
  });

  /// Clé d'API Google.
  final String apiKey;

  /// Transport HTTP.
  final HttpTransport http;

  final _cache = <String, PagePreview>{};

  /// Champs demandés : adresse finale, erreur et audits (qui contiennent la
  /// capture). Le filtre ne peut pas viser l'audit `final-screenshot`
  /// lui-même (Google refuse le tiret, vérifié le 27/11/2026) ; compressée,
  /// la réponse pèse de 30 à 200 Ko environ.
  static const fields =
      'lighthouseResult(finalDisplayedUrl,runtimeError,audits)';

  /// Photo de [url] ; lève [PagePreviewException] en cas d'échec.
  Future<PagePreview> capture(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;
    final uri = Uri.https(
      'www.googleapis.com',
      '/pagespeedonline/v5/runPagespeed',
      {
        'url': url,
        'strategy': 'mobile',
        'category': 'performance',
        'fields': fields,
      },
    );
    HttpReply reply;
    try {
      reply = await http.get(
        uri,
        headers: {'X-Goog-Api-Key': apiKey, 'Accept-Encoding': 'gzip'},
      );
    } on OnlineLookupException {
      throw const PagePreviewException('UNAVAILABLE');
    }
    final preview = parse(reply);
    _cache[url] = preview;
    return preview;
  }

  /// Lit la réponse de PageSpeed Insights.
  static PagePreview parse(HttpReply reply) {
    Map<String, Object?> json;
    try {
      final decoded = jsonDecode(utf8.decode(reply.body));
      json = decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      json = const {};
    }
    if (reply.statusCode == 429) throw const PagePreviewException('QUOTA');
    if (reply.statusCode != 200) {
      final message = '${(json['error'] as Map?)?['message'] ?? ''}';
      // Lighthouse n'a pas pu charger la page (nom inexistant, site fermé,
      // erreur du serveur).
      if (reply.statusCode >= 400 &&
          reply.statusCode < 600 &&
          message.contains('Lighthouse')) {
        throw const PagePreviewException('PAGE_UNREACHABLE');
      }
      throw const PagePreviewException('UNAVAILABLE');
    }
    final result = json['lighthouseResult'];
    if (result is! Map) throw const PagePreviewException('UNAVAILABLE');
    if (result['runtimeError'] is Map) {
      throw const PagePreviewException('PAGE_UNREACHABLE');
    }
    final data =
        (((result['audits'] as Map?)?['final-screenshot'] as Map?)?['details']
            as Map?)?['data'];
    if (data is! String || !data.startsWith('data:image/')) {
      throw const PagePreviewException('PAGE_UNREACHABLE');
    }
    final comma = data.indexOf(',');
    final Uint8List image;
    try {
      image = base64Decode(data.substring(comma + 1));
    } on FormatException {
      throw const PagePreviewException('UNAVAILABLE');
    }
    final finalUrl = result['finalDisplayedUrl'];
    return PagePreview(
      screenshot: image,
      finalUrl: finalUrl is String && finalUrl.isNotEmpty ? finalUrl : null,
    );
  }
}
