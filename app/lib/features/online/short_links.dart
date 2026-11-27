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

  /// Navigateur d'un téléphone Android : certains services (liens
  /// d'application, pages d'arnaque) envoient chaque appareil ailleurs ; on
  /// veut la destination qu'aurait le téléphone de l'utilisateur.
  static const androidBrowser =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

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
      reply = await http.get(uri, headers: {'User-Agent': androidBrowser});
    } on OnlineLookupException {
      return null;
    }
    final location = reply.location?.trim();
    if (reply.statusCode < 300 || reply.statusCode >= 400 || location == null) {
      return null;
    }
    final app = appStoreWebPage(location);
    if (app != null) return _parse(app);
    final target = uri.resolve(location);
    // Page d'avertissement de Bitly : la destination est en paramètre.
    if (target.host == 'bitly.com' && target.path.startsWith('/a/warning')) {
      final warned = target.queryParameters['url'];
      if (warned != null) return _parse(warned);
    }
    return _parse(target.toString());
  }

  /// Page web équivalente à une adresse qui ouvre une application :
  /// `market://details?id=…` (Play Store), `intent://…;package=…;end`
  /// (Android : sa page de secours si elle existe, sinon le Play Store),
  /// `itms-apps://…` (App Store). `null` pour une adresse web.
  static String? appStoreWebPage(String location) {
    final Uri uri;
    try {
      uri = Uri.parse(location);
    } on FormatException {
      return null;
    }
    String play(String package) => Uri.https(
      'play.google.com',
      '/store/apps/details',
      {'id': package},
    ).toString();
    switch (uri.scheme.toLowerCase()) {
      case 'market':
        final id = uri.queryParameters['id'];
        return id == null || id.isEmpty ? null : play(id);
      case 'intent':
        // intent://…#Intent;scheme=…;package=…;S.browser_fallback_url=…;end
        final extras = {
          for (final part in uri.fragment.split(';'))
            if (part.contains('='))
              part.substring(0, part.indexOf('=')): _decode(
                part.substring(part.indexOf('=') + 1),
              ),
        };
        final fallback = extras['S.browser_fallback_url'];
        if (fallback != null && fallback.startsWith('http')) return fallback;
        final package = extras['package'];
        return package == null || package.isEmpty ? null : play(package);
      case 'itms-apps':
      case 'itms-appss':
        return uri.replace(scheme: 'https', host: 'apps.apple.com').toString();
      default:
        return null;
    }
  }

  /// Décodage `%XX` sans exception : texte brut si l'encodage est invalide.
  static String _decode(String value) {
    if (RegExp('%(?![0-9A-Fa-f]{2})').hasMatch(value)) return value;
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
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
