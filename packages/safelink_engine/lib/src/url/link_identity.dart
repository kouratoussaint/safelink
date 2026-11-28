import 'package:meta/meta.dart';
import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/url_rules.dart';

/// Nature d'un lien, à dire simplement à l'utilisateur : « C'est un
/// fichier Google Drive », « C'est un lien WhatsApp »…
///
/// Ce n'est pas un indice : la nature d'un lien ne le rend ni sûr ni
/// dangereux. Elle explique ce qu'il ouvrirait.
enum LinkKind {
  /// Fichier déposé sur un service de partage (Google Drive, Dropbox…).
  sharedFile,

  /// Dossier partagé.
  sharedFolder,

  /// Document en ligne (Google Docs, Sheets, Slides).
  document,

  /// Formulaire à remplir (Google Forms, Microsoft Forms…).
  form,

  /// Lieu sur une carte.
  map,

  /// Page d'une application dans un magasin (Google Play, App Store) ;
  /// [LinkIdentity.detail] : identifiant de l'application, s'il est connu.
  appStore,

  /// Fichier d'application Android à installer hors du magasin
  /// (`.apk`) ; [LinkIdentity.detail] : extension.
  appFile,

  /// Fichier à télécharger ; [LinkIdentity.detail] : extension (`pdf`,
  /// `zip`, `exe`…).
  file,

  /// Vidéo.
  video,

  /// Discussion avec une personne ; [LinkIdentity.detail] : numéro
  /// (`+22670123456`) ou nom, s'il est dans le lien.
  chat,

  /// Invitation à entrer dans un groupe.
  groupInvite,

  /// Chaîne ou compte à suivre ; [LinkIdentity.detail] : nom, s'il est
  /// dans le lien.
  channel,

  /// Publication sur un réseau social.
  post,

  /// Groupe sur un réseau social.
  group,

  /// Profil ou page sur un réseau social.
  profile,

  /// Offre d'emploi.
  job,

  /// Page qui rassemble des liens (Linktree).
  linkPage,

  /// Lien raccourci, qui cache sa destination ; [LinkIdentity.service] :
  /// service de raccourci.
  shortLink,

  /// Page que n'importe qui peut créer sur une plateforme ;
  /// [LinkIdentity.service] : plateforme.
  userPage,

  /// Domaine officiel d'une marque de référence ; [LinkIdentity.detail] :
  /// nom de la marque. Ce qui ne garantit pas que la page est sûre.
  officialSite,

  /// Nom de site qui imite une marque de référence ;
  /// [LinkIdentity.detail] : nom de la marque.
  imitation,

  /// Site désigné par une adresse numérique (IP), sans nom ;
  /// [LinkIdentity.detail] : adresse.
  ipAddress,

  /// Site web ordinaire ; [LinkIdentity.detail] : domaine.
  website,
}

/// Ce qu'est un lien : nature, service reconnu et précision utile.
@immutable
final class LinkIdentity {
  /// Crée une description.
  const new(
    this.kind, {
    this.service,
    this.detail,
    this.prefilledMessage = false,
  });

  /// Décrit [url], d'après son adresse seulement (aucun accès au réseau).
  ///
  /// [brandMatches] : rapprochements avec les marques de référence, tels
  /// que les donne l'analyse du lien.
  factory of(ParsedUrl url, {Iterable<BrandMatch> brandMatches = const []}) =>
      LinkDescriber.describe(url, brandMatches: brandMatches);

  /// Nature du lien.
  final LinkKind kind;

  /// Service reconnu, nom propre (« Google Drive », « WhatsApp »).
  final String? service;

  /// Précision selon [kind] : numéro, nom, identifiant d'application,
  /// extension, marque ou domaine.
  final String? detail;

  /// Lien de discussion qui propose un message déjà écrit (`?text=`).
  final bool prefilledMessage;

  @override
  bool operator ==(Object other) =>
      other is LinkIdentity &&
      other.kind == kind &&
      other.service == service &&
      other.detail == detail &&
      other.prefilledMessage == prefilledMessage;

  @override
  int get hashCode => Object.hash(kind, service, detail, prefilledMessage);

  @override
  String toString() => 'LinkIdentity(${kind.name}, $service)';
}

/// Règles qui reconnaissent la nature d'un lien.
///
/// Ordre : adresse IP ; fichier à télécharger (d'après l'extension) ;
/// services connus (hôte et chemin) ; lien raccourci ; domaine officiel
/// ou imitation d'une marque ; page créée sur une plateforme ouverte à
/// tous ; site web ordinaire.
abstract final class LinkDescriber {
  /// Extensions de fichiers reconnues, hors applications Android.
  static const fileExtensions = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'txt', //
    'zip', 'rar', '7z', 'exe', 'msi', 'bat', 'scr', 'jar', 'dmg', 'ipa',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'mkv', 'mp3',
    'm4a', 'wav',
  };

  /// Décrit [url] ; voir [LinkIdentity.of].
  static LinkIdentity describe(
    ParsedUrl url, {
    Iterable<BrandMatch> brandMatches = const [],
  }) {
    if (url.hostType != UrlHostType.domain) {
      return LinkIdentity(LinkKind.ipAddress, detail: url.host);
    }
    final host = url.host;
    final registrable = url.registrableDomain ?? host;
    final service = _service(url, host, registrable);

    final extension = _extension(url.path);
    if (extension != null) {
      if (UrlRules.apkExtensions.contains('.$extension')) {
        return LinkIdentity(
          LinkKind.appFile,
          service: service?.service,
          detail: extension,
        );
      }
      if (fileExtensions.contains(extension)) {
        return LinkIdentity(
          LinkKind.file,
          service: service?.service,
          detail: extension,
        );
      }
    }
    if (service != null) return service;

    if (UrlRules.shorteners.contains(registrable)) {
      return LinkIdentity(LinkKind.shortLink, service: registrable);
    }

    final matches = brandMatches.toList();
    final official = matches
        .where((m) => m.kind == BrandMatchKind.official)
        .firstOrNull;
    if (official != null) {
      return LinkIdentity(LinkKind.officialSite, detail: official.brand.name);
    }
    final imitated = matches.firstOrNull;
    if (imitated != null) {
      return LinkIdentity(LinkKind.imitation, detail: imitated.brand.name);
    }

    final suffix = url.publicSuffix;
    if (suffix != null && suffix.isPrivateSuffix) {
      return LinkIdentity(LinkKind.userPage, service: suffix.publicSuffix);
    }
    if (UrlRules.userContentHosts.contains(host) ||
        UrlRules.userContentHosts.contains(registrable)) {
      return LinkIdentity(LinkKind.userPage, service: registrable);
    }
    return LinkIdentity(LinkKind.website, detail: url.hostUnicode);
  }

  /// Extension du dernier segment du chemin, en minuscules.
  static String? _extension(String path) {
    final last = path.split('/').last;
    final dot = last.lastIndexOf('.');
    if (dot <= 0 || dot == last.length - 1) return null;
    final extension = last.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension) ? extension : null;
  }

  /// Segments du chemin, sans les vides.
  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  static String? _query(ParsedUrl url, String name) => url.queryParameters
      .where((p) => p.name == name && p.value.trim().isNotEmpty)
      .map((p) => p.value.trim())
      .firstOrNull;

  /// Numéro de téléphone international (chiffres seuls), ou `null`.
  static String? _phone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[\s+().-]'), '');
    return RegExp(r'^\d{7,15}$').hasMatch(digits) ? '+$digits' : null;
  }

  /// Domaines des services reconnus, le plus précis d'abord : un hôte
  /// leur correspond s'il est ce domaine ou l'un de ses sous-domaines.
  static const _serviceDomains = [
    'app.goo.gl', 'goo.gl', 'wa.me', 'whatsapp.com', 't.me', 'telegram.me', //
    'm.me', 'messenger.com', 'forms.gle', 'youtu.be', 'youtube.com',
    'apple.com', 'fb.watch', 'facebook.com', 'fb.com', 'instagram.com',
    'tiktok.com', 'x.com', 'twitter.com', 'linkedin.com', 'snapchat.com',
    'dropbox.com', 'dropboxusercontent.com', 'db.tt', '1drv.ms', 'live.com',
    'sharepoint.com', 'office.com', 'microsoft.com', 'wetransfer.com',
    'we.tl', 'mega.nz', 'mega.io', 'mediafire.com', 'jotform.com',
    'typeform.com', 'linktr.ee', 'telegra.ph', 'notion.site', 'notion.so',
    'canva.site', 'googleapis.com',
  ];

  static LinkIdentity? _service(
    ParsedUrl url,
    String host,
    String registrable,
  ) {
    final path = url.path.toLowerCase();
    final segments = _segments(url.path);
    final first = segments.firstOrNull?.toLowerCase();
    bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
    final domain = _serviceDomains
        .where((d) => host == d || host.endsWith('.$d'))
        .firstOrNull;

    switch (domain) {
      case 'wa.me':
        final prefilled = _query(url, 'text') != null;
        if (first == null || first == 'message' || first == 'qr') {
          return LinkIdentity(
            LinkKind.chat,
            service: 'WhatsApp',
            prefilledMessage: prefilled,
          );
        }
        return LinkIdentity(
          LinkKind.chat,
          service: 'WhatsApp',
          detail: _phone(first),
          prefilledMessage: prefilled,
        );
      case 'whatsapp.com':
        if (host == 'chat.whatsapp.com') {
          return const LinkIdentity(LinkKind.groupInvite, service: 'WhatsApp');
        }
        if (first == 'channel') {
          return const LinkIdentity(LinkKind.channel, service: 'WhatsApp');
        }
        if (first == 'send' || host == 'api.whatsapp.com') {
          return LinkIdentity(
            LinkKind.chat,
            service: 'WhatsApp',
            detail: _phone(_query(url, 'phone')),
            prefilledMessage: _query(url, 'text') != null,
          );
        }
        return null;
      case 't.me' || 'telegram.me':
        if (first == null) return null;
        if (first.startsWith('+') || first == 'joinchat') {
          return const LinkIdentity(LinkKind.groupInvite, service: 'Telegram');
        }
        final name = first == 's' ? segments.elementAtOrNull(1) : first;
        return LinkIdentity(
          LinkKind.channel,
          service: 'Telegram',
          detail: name == null ? null : '@$name',
        );
      case 'm.me':
        return LinkIdentity(LinkKind.chat, service: 'Messenger', detail: first);
      case 'messenger.com':
        return under('/t')
            ? const LinkIdentity(LinkKind.chat, service: 'Messenger')
            : null;
      case 'forms.gle':
        return const LinkIdentity(LinkKind.form, service: 'Google Forms');
      case 'youtu.be':
        return const LinkIdentity(LinkKind.video, service: 'YouTube');
      case 'youtube.com':
        if (under('/watch') ||
            under('/shorts') ||
            under('/live') ||
            under('/embed')) {
          return const LinkIdentity(LinkKind.video, service: 'YouTube');
        }
        if (first != null &&
            (first.startsWith('@') ||
                first == 'channel' ||
                first == 'c' ||
                first == 'user')) {
          return const LinkIdentity(LinkKind.channel, service: 'YouTube');
        }
        return null;
      case 'apple.com':
        return host == 'apps.apple.com' || host == 'itunes.apple.com'
            ? const LinkIdentity(LinkKind.appStore, service: 'App Store')
            : null;
      case 'goo.gl':
        return first == 'maps'
            ? const LinkIdentity(LinkKind.map, service: 'Google Maps')
            : null;
      case 'app.goo.gl':
        return host == 'maps.app.goo.gl'
            ? const LinkIdentity(LinkKind.map, service: 'Google Maps')
            : null;
      case 'fb.watch':
        return const LinkIdentity(LinkKind.video, service: 'Facebook');
      case 'facebook.com' || 'fb.com':
        return _facebook(path, first);
      case 'instagram.com':
        if (first == null) return null;
        return switch (first) {
          'reel' ||
          'reels' ||
          'tv' => const LinkIdentity(LinkKind.video, service: 'Instagram'),
          'p' ||
          'stories' => const LinkIdentity(LinkKind.post, service: 'Instagram'),
          _ => const LinkIdentity(LinkKind.profile, service: 'Instagram'),
        };
      case 'tiktok.com':
        if (host == 'vm.tiktok.com' ||
            host == 'vt.tiktok.com' ||
            first == 't' ||
            path.contains('/video/')) {
          return const LinkIdentity(LinkKind.video, service: 'TikTok');
        }
        return first != null && first.startsWith('@')
            ? const LinkIdentity(LinkKind.profile, service: 'TikTok')
            : null;
      case 'x.com' || 'twitter.com':
        if (first == null) return null;
        return segments.elementAtOrNull(1)?.toLowerCase() == 'status'
            ? const LinkIdentity(LinkKind.post, service: 'X')
            : const LinkIdentity(LinkKind.profile, service: 'X');
      case 'linkedin.com':
        return switch (first) {
          'jobs' => const LinkIdentity(LinkKind.job, service: 'LinkedIn'),
          'in' || 'company' => const LinkIdentity(
            LinkKind.profile,
            service: 'LinkedIn',
          ),
          'posts' ||
          'feed' => const LinkIdentity(LinkKind.post, service: 'LinkedIn'),
          _ => null,
        };
      case 'snapchat.com':
        return first == 'add'
            ? const LinkIdentity(LinkKind.profile, service: 'Snapchat')
            : null;
      case 'dropbox.com' || 'dropboxusercontent.com' || 'db.tt':
        final folder =
            under('/sh') || under('/scl/fo') || path.contains('/folder');
        return LinkIdentity(
          folder ? LinkKind.sharedFolder : LinkKind.sharedFile,
          service: 'Dropbox',
        );
      case '1drv.ms':
        return const LinkIdentity(LinkKind.sharedFile, service: 'OneDrive');
      case 'live.com':
        return host == 'onedrive.live.com'
            ? const LinkIdentity(LinkKind.sharedFile, service: 'OneDrive')
            : null;
      case 'sharepoint.com':
        return const LinkIdentity(LinkKind.sharedFile, service: 'SharePoint');
      case 'office.com' || 'microsoft.com':
        return host.startsWith('forms.')
            ? const LinkIdentity(LinkKind.form, service: 'Microsoft Forms')
            : null;
      case 'wetransfer.com' || 'we.tl':
        return const LinkIdentity(LinkKind.sharedFile, service: 'WeTransfer');
      case 'mega.nz' || 'mega.io':
        return LinkIdentity(
          first == 'folder' ? LinkKind.sharedFolder : LinkKind.sharedFile,
          service: 'MEGA',
        );
      case 'mediafire.com':
        return LinkIdentity(
          first == 'folder' ? LinkKind.sharedFolder : LinkKind.sharedFile,
          service: 'MediaFire',
        );
      case 'jotform.com':
        return const LinkIdentity(LinkKind.form, service: 'Jotform');
      case 'typeform.com':
        return const LinkIdentity(LinkKind.form, service: 'Typeform');
      case 'linktr.ee':
        return const LinkIdentity(LinkKind.linkPage, service: 'Linktree');
      case 'telegra.ph':
        return const LinkIdentity(LinkKind.userPage, service: 'Telegraph');
      case 'notion.site' || 'notion.so':
        return const LinkIdentity(LinkKind.userPage, service: 'Notion');
      case 'canva.site':
        return const LinkIdentity(LinkKind.userPage, service: 'Canva');
      case 'googleapis.com':
        return host == 'storage.googleapis.com' ||
                host == 'firebasestorage.googleapis.com'
            ? const LinkIdentity(LinkKind.sharedFile, service: 'Google Cloud')
            : null;
    }
    if (registrable.startsWith('google.')) return _google(url, host, path);
    return null;
  }

  static LinkIdentity? _google(ParsedUrl url, String host, String path) {
    bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
    switch (host) {
      case 'docs.google.com':
        if (under('/forms')) {
          return const LinkIdentity(LinkKind.form, service: 'Google Forms');
        }
        if (under('/spreadsheets')) {
          return const LinkIdentity(
            LinkKind.document,
            service: 'Google Sheets',
          );
        }
        if (under('/presentation')) {
          return const LinkIdentity(
            LinkKind.document,
            service: 'Google Slides',
          );
        }
        return const LinkIdentity(LinkKind.document, service: 'Google Docs');
      case 'drive.google.com':
        return LinkIdentity(
          path.contains('/folders/')
              ? LinkKind.sharedFolder
              : LinkKind.sharedFile,
          service: 'Google Drive',
        );
      case 'sites.google.com':
        return const LinkIdentity(LinkKind.userPage, service: 'Google Sites');
      case 'play.google.com':
        return LinkIdentity(
          LinkKind.appStore,
          service: 'Google Play',
          detail: _query(url, 'id'),
        );
    }
    if (host.startsWith('maps.') || under('/maps')) {
      return const LinkIdentity(LinkKind.map, service: 'Google Maps');
    }
    return null;
  }

  static LinkIdentity? _facebook(String path, String? first) {
    if (first == null) return null;
    bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
    if (first == 'groups') {
      return const LinkIdentity(LinkKind.group, service: 'Facebook');
    }
    if (first == 'marketplace') {
      return const LinkIdentity(LinkKind.post, service: 'Facebook Marketplace');
    }
    if (under('/watch') ||
        under('/reel') ||
        under('/share/v') ||
        under('/share/r') ||
        path.contains('/videos/')) {
      return const LinkIdentity(LinkKind.video, service: 'Facebook');
    }
    if (first == 'share' ||
        first == 'permalink.php' ||
        first == 'story.php' ||
        first == 'photo' ||
        first == 'photo.php' ||
        path.contains('/posts/') ||
        path.contains('/photos/')) {
      return const LinkIdentity(LinkKind.post, service: 'Facebook');
    }
    return const LinkIdentity(LinkKind.profile, service: 'Facebook');
  }
}
