import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/features/online/transports.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Vraie destination d'un lien raccourci (bit.ly, tinyurl.com…).
///
/// Seul le service de raccourcissement est contacté : il répond par une
/// redirection dont on lit l'adresse, sans la suivre. La destination
/// elle-même n'est jamais contactée par le téléphone (ADR 0012).
final class ShortLinkResolver {
  /// Crée le résolveur.
  new({
    this.http = const IoHttpTransport(
      timeout: Duration(seconds: 6),
      maxBytes: 64 * 1024,
    ),
  });

  /// Transport HTTP.
  final HttpTransport http;

  /// Nombre maximal de raccourcisseurs enchaînés.
  static const maxHops = 5;

  final _parser = UrlParser();
  final _cache = <String, ParsedUrl?>{};

  /// Vrai si [url] passe par un raccourcisseur connu.
  static bool isShortener(ParsedUrl url) =>
      UrlRules.shorteners.contains(url.registrableDomain);

  /// Destination de [url], ou `null` si ce n'est pas un lien raccourci, si
  /// le service ne répond pas ou ne redirige pas. Ne lève jamais
  /// d'exception.
  Future<ParsedUrl?> resolve(ParsedUrl url) async {
    if (!isShortener(url)) return null;
    if (_cache.containsKey(url.href)) return _cache[url.href];
    var current = url;
    ParsedUrl? destination;
    for (var hop = 0; hop < maxHops && isShortener(current); hop++) {
      final next = await _next(current);
      if (next == null) break;
      destination = current = next;
    }
    return _cache[url.href] = destination;
  }

  /// Adresse vers laquelle [url] redirige, sans la suivre.
  Future<ParsedUrl?> _next(ParsedUrl url) async {
    // Toujours en HTTPS : la requête ne passe jamais en clair.
    final uri = Uri.parse(url.href).replace(scheme: 'https');
    final HttpReply reply;
    try {
      reply = await http.get(uri);
    } on OnlineLookupException {
      return null;
    }
    final location = reply.location;
    if (reply.statusCode < 300 || reply.statusCode >= 400 || location == null) {
      return null;
    }
    final target = uri.resolve(location.trim());
    // Page d'avertissement de Bitly : la destination est en paramètre.
    if (target.host == 'bitly.com' && target.path.startsWith('/a/warning')) {
      final warned = target.queryParameters['url'];
      if (warned != null) return _parse(warned);
    }
    return _parse(target.toString());
  }

  ParsedUrl? _parse(String text) => switch (_parser.parse(text)) {
    final ParsedUrl parsed => parsed,
    _ => null,
  };
}

/// Résolveur des liens raccourcis de l'application.
final shortLinkResolverProvider = Provider<ShortLinkResolver>(
  (ref) => ShortLinkResolver(),
);
