import 'package:flutter/foundation.dart' show immutable;
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Contenu reçu d'une autre application par « Partager → SafeLink ».
///
/// Le texte n'est jamais affiché dans les journaux : il peut contenir des
/// données privées.
@immutable
sealed class SharedContent {
  const new();

  /// Lit la description envoyée par l'activité Android (`MainActivity`), ou
  /// `null` si [raw] n'est pas un partage.
  static SharedContent? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    if (raw['unreadable'] == true) return const SharedNothing();
    final text = raw['text'];
    final files = raw['files'] == true;
    final hasText = text is String && text.trim().isNotEmpty;
    if (hasText) {
      return SharedText(
        text,
        truncated: raw['truncated'] == true,
        filesIgnored: files,
      );
    }
    if (files) {
      final type = raw['type'];
      return SharedFiles(
        type is String
            ? SharedFileKind.fromMimeType(type)
            : SharedFileKind.other,
      );
    }
    return const SharedNothing();
  }
}

/// Texte partagé : un lien, un message, ou les deux.
final class SharedText extends SharedContent {
  /// Crée un texte partagé.
  const new(this.text, {this.truncated = false, this.filesIgnored = false});

  /// Texte reçu, borné par l'activité Android.
  final String text;

  /// Le texte reçu était plus long et a été coupé.
  final bool truncated;

  /// Un fichier accompagnait le texte : il n'a pas été ouvert.
  final bool filesIgnored;

  @override
  bool operator ==(Object other) =>
      other is SharedText &&
      other.text == text &&
      other.truncated == truncated &&
      other.filesIgnored == filesIgnored;

  @override
  int get hashCode => Object.hash(text, truncated, filesIgnored);

  @override
  String toString() => 'SharedText(${text.length})';
}

/// Nature d'un fichier partagé, pour le dire avec un pictogramme.
enum SharedFileKind {
  /// Photo ou image.
  image,

  /// Vidéo.
  video,

  /// Tout autre fichier.
  other;

  /// Nature déduite du type MIME annoncé.
  static SharedFileKind fromMimeType(String type) {
    final lower = type.toLowerCase();
    if (lower.startsWith('image/')) return image;
    if (lower.startsWith('video/')) return video;
    return other;
  }
}

/// Fichiers partagés sans texte : jamais ouverts dans cette version.
final class SharedFiles extends SharedContent {
  /// Crée un partage de fichiers.
  const new(this.kind);

  /// Nature des fichiers.
  final SharedFileKind kind;

  @override
  bool operator ==(Object other) => other is SharedFiles && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'SharedFiles(${kind.name})';
}

/// Partage vide ou illisible.
final class SharedNothing extends SharedContent {
  /// Crée un partage vide.
  const new();

  @override
  bool operator ==(Object other) => other is SharedNothing;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SharedNothing()';
}

/// Lien repéré dans un texte partagé, prêt à être proposé.
@immutable
final class SharedLink {
  /// Crée un lien proposé.
  const new({required this.url, required this.displayed, required this.domain});

  /// Lien à analyser (forme déguisée rétablie).
  final String url;

  /// Lien affichable, données sensibles masquées et longueur bornée.
  final String displayed;

  /// Domaine mis en évidence (domaine enregistré, sinon hôte).
  final String domain;

  @override
  bool operator ==(Object other) => other is SharedLink && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'SharedLink(…)';
}

/// Ce que SafeLink fait d'un partage.
@immutable
sealed class SharePlan {
  const new();
}

/// Rien à choisir : l'analyse démarre tout de suite.
final class AnalyzeShared extends SharePlan {
  /// Crée le plan.
  const new(this.request);

  /// Analyse à lancer.
  final AnalysisRequest request;
}

/// Plusieurs possibilités : l'utilisateur choisit sur l'écran de partage.
final class ChooseShared extends SharePlan {
  /// Crée le plan.
  const new({
    required this.content,
    required this.messageText,
    required this.links,
    required this.long,
  });

  /// Partage reçu.
  final SharedText content;

  /// Texte analysé par « Tout le message », borné à la taille d'un message
  /// analysable.
  final String messageText;

  /// Liens du texte, dans l'ordre, sans doublon.
  final List<SharedLink> links;

  /// Texte trop long : « Tout le message » n'en vérifie que le début.
  final bool long;
}

/// Rien d'analysable : l'écran de partage l'explique.
final class RefuseShared extends SharePlan {
  /// Crée le plan.
  const new(this.content);

  /// Partage reçu ([SharedFiles] ou [SharedNothing]).
  final SharedContent content;
}

/// Décide quoi faire d'un partage.
///
/// - Un lien seul (le cas d'un navigateur ou de YouTube) : analysé tout de
///   suite comme un lien.
/// - Un texte sans lien : analysé tout de suite comme un message.
/// - Un texte avec des liens, trop long, ou accompagné d'un fichier : écran
///   de choix (« Tout le message » ou « Le lien seulement »).
/// - Fichiers seuls, partage vide ou illisible : refus expliqué.
SharePlan planShare(
  SharedContent content, {
  UrlParser? parser,
  int maxMessageLength = MessageAnalyzer.defaultMaxLength,
}) {
  if (content is! SharedText) return RefuseShared(content);
  final text = content.text;
  final urlParser = parser ?? UrlParser();
  final extraction = MessageExtractor(parser: urlParser)
      .extract(MessagePreprocessor.prepare(text));
  final links = <SharedLink>[];
  final seen = <String>{};
  for (final link in extraction.links) {
    if (!seen.add(link.url)) continue;
    links.add(_describe(link.url, urlParser));
  }
  final runes = text.runes;
  final long = content.truncated || runes.length > maxMessageLength;
  final messageText = runes.length > maxMessageLength
      ? String.fromCharCodes(runes.take(maxMessageLength))
      : text;
  final direct = !long && !content.filesIgnored;
  if (direct && links.isEmpty) {
    return AnalyzeShared(AnalysisRequest(AnalysisKind.message, text));
  }
  if (direct && extraction.links.length == 1) {
    final only = extraction.links.single;
    final rest =
        text.substring(0, only.span.start) + text.substring(only.span.end);
    if (_onlyPunctuation.hasMatch(rest)) {
      return AnalyzeShared(AnalysisRequest(AnalysisKind.link, only.url));
    }
  }
  return ChooseShared(
    content: content,
    messageText: messageText,
    links: List.unmodifiable(links),
    long: long,
  );
}

/// Espaces, ponctuation et symboles seulement : rien d'autre que le lien.
final _onlyPunctuation = RegExp(r'^[\s\p{P}\p{S}]*$', unicode: true);

SharedLink _describe(String url, UrlParser parser) {
  final parsed = parser.parse(url);
  if (parsed is ParsedUrl) {
    return SharedLink(
      url: url,
      displayed: UrlMasking.truncate(UrlMasking.maskedHref(parsed), 120),
      domain: parsed.registrableDomain ?? parsed.host,
    );
  }
  return SharedLink(
    url: url,
    displayed: UrlMasking.truncate(url, 120),
    domain: '',
  );
}
