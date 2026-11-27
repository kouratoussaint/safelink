import 'package:meta/meta.dart';
import 'package:safelink_engine/src/message/message_text.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/url_parser.dart';

/// Lien repéré dans un message.
@immutable
final class ExtractedLink {
  /// Crée un lien repéré.
  const new({
    required this.span,
    required this.written,
    required this.url,
    required this.isDefanged,
    required this.hasScheme,
  });

  /// Position dans le texte d'origine.
  final MessageSpan span;

  /// Lien tel qu'il est écrit.
  final String written;

  /// Lien à analyser : forme déguisée rétablie (`hxxp` → `http`, `[.]` →
  /// `.`).
  final String url;

  /// Vrai si le lien était écrit sous une forme déguisée ou neutralisée.
  final bool isDefanged;

  /// Vrai si le lien indiquait son protocole.
  final bool hasScheme;

  @override
  bool operator ==(Object other) =>
      other is ExtractedLink && other.span == span && other.url == url;

  @override
  int get hashCode => Object.hash(span, url);

  @override
  String toString() => 'ExtractedLink(${span.start}, ${span.end})';
}

/// Numéro de téléphone repéré.
@immutable
final class ExtractedPhoneNumber {
  /// Crée un numéro repéré.
  const new(this.span, this.digits);

  /// Position dans le texte d'origine.
  final MessageSpan span;

  /// Chiffres seuls, précédés de `+` pour un numéro international.
  final String digits;

  /// Vrai pour un numéro au format international (`+226…`, `00226…`).
  bool get isInternational => digits.startsWith('+');

  @override
  bool operator ==(Object other) =>
      other is ExtractedPhoneNumber &&
      other.span == span &&
      other.digits == digits;

  @override
  int get hashCode => Object.hash(span, digits);

  @override
  String toString() => 'ExtractedPhoneNumber(${span.start}, ${span.end})';
}

/// Code USSD repéré (`*144#`, `*144*2*1#`).
@immutable
final class ExtractedUssdCode {
  /// Crée un code repéré.
  const new(this.span, this.code);

  /// Position dans le texte d'origine.
  final MessageSpan span;

  /// Code tel qu'il serait composé, sans espaces.
  final String code;

  /// Groupes de chiffres du code (`*144*2*70123456#` → `144`, `2`,
  /// `70123456`).
  List<String> get groups =>
      code.split(RegExp('[*#]')).where((g) => g.isNotEmpty).toList();

  /// Vrai si le code contient un numéro de téléphone ou un montant (groupe
  /// d'au moins 4 chiffres après le code de service) : composer ce code
  /// peut déclencher un transfert d'argent.
  bool get carriesTransferData => groups.skip(1).any((g) => g.length >= 4);

  @override
  bool operator ==(Object other) =>
      other is ExtractedUssdCode && other.span == span && other.code == code;

  @override
  int get hashCode => Object.hash(span, code);

  @override
  String toString() => 'ExtractedUssdCode($code)';
}

/// Montant en francs CFA repéré.
@immutable
final class ExtractedAmount {
  /// Crée un montant repéré.
  const new(this.span, this.value);

  /// Position dans le texte d'origine.
  final MessageSpan span;

  /// Valeur en francs CFA, partie décimale ignorée.
  final int value;

  @override
  bool operator ==(Object other) =>
      other is ExtractedAmount && other.span == span && other.value == value;

  @override
  int get hashCode => Object.hash(span, value);

  @override
  String toString() => 'ExtractedAmount($value)';
}

/// Éléments repérés dans un message.
final class MessageExtraction {
  /// Crée le résultat d'une extraction.
  new({
    required List<ExtractedLink> links,
    required List<ExtractedPhoneNumber> phoneNumbers,
    required List<ExtractedUssdCode> ussdCodes,
    required List<ExtractedAmount> amounts,
  }) : links = List.unmodifiable(links),
       phoneNumbers = List.unmodifiable(phoneNumbers),
       ussdCodes = List.unmodifiable(ussdCodes),
       amounts = List.unmodifiable(amounts);

  /// Liens, dans l'ordre du texte.
  final List<ExtractedLink> links;

  /// Numéros de téléphone, dans l'ordre du texte.
  final List<ExtractedPhoneNumber> phoneNumbers;

  /// Codes USSD, dans l'ordre du texte.
  final List<ExtractedUssdCode> ussdCodes;

  /// Montants en francs CFA, dans l'ordre du texte.
  final List<ExtractedAmount> amounts;
}

/// Repère les liens (y compris `www.`, domaines nus et formes déguisées), les
/// numéros, les codes USSD et les montants en francs CFA.
final class MessageExtractor {
  /// Crée un extracteur ; [parser] valide les liens repérés.
  new({UrlParser? parser}) : _parser = parser ?? UrlParser();

  final UrlParser _parser;

  /// Protocole écrit normalement ou déguisé (`hxxp`, `h**p`, `h[tt]p`), puis
  /// `://` éventuellement entre crochets.
  static final _schemeLink = RegExp(
    r'(?<![\p{L}\p{N}@])(?:https?|hxxps?|h\*\*ps?|h\[tt\]ps?|hxxp\[s\])'
    r'(?:://|\[://\]|\[:\]//|:\\\\)[^\s<>"]+',
    caseSensitive: false,
    unicode: true,
  );

  static final _wwwLink = RegExp(
    r'(?<![\p{L}\p{N}@./\-])www(?:\.|\[\.\]|\(\.\))[^\s<>"]+',
    caseSensitive: false,
    unicode: true,
  );

  /// Nom de domaine nu : labels séparés par un point, éventuellement
  /// déguisé (`[.]`, `(.)`, `{.}`, `[dot]`, `(dot)`).
  static final _bareLink = RegExp(
    r'(?<![\p{L}\p{N}@./\-_])'
    r'(?:[\p{L}\p{N}](?:[\p{L}\p{N}\-]{0,62}[\p{L}\p{N}])?'
    r'(?:\.|\[\.\]|\(\.\)|\{\.\}|\[dot\]|\(dot\)))+'
    r'\p{L}{2,63}(?::\d{2,5})?(?:[/?#][^\s<>"]*)?',
    caseSensitive: false,
    unicode: true,
  );

  static final _defangedDot = RegExp(
    r'\[\.\]|\(\.\)|\{\.\}|\[dot\]|\(dot\)',
    caseSensitive: false,
  );

  static const _trailing = '.,;:!?»"\'’\u201D)]}…>';

  static final _ussd = RegExp(r'(?<![\w*#])[*#]\d{1,4}(?:\*\d{1,20})*#');

  static final _amount = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:[ .]\d{3})+|\d+)(?:,\d{1,2})?\s?'
    r'(?:f\s?cfa|cfa|xof|francs?(?:\s?cfa)?|frs?|f)(?![a-z])',
  );

  static final _amountPrefix = RegExp(
    r'(?<![a-z])(?:fcfa|xof)\s?(\d{1,3}(?:[ .]\d{3})+|\d+)(?![\d])',
  );

  static final _internationalPhone = RegExp(
    r'(?<![\d*#+])(?:\+|00)\d(?:[ .\-]?\d){7,13}(?![\d*#])',
  );

  static final _localPhone = RegExp(
    r'(?<![\d*#+,.])\d{2}(?:[ .\-]?\d{2}){3}(?![\d*#])',
  );

  /// Extrait les éléments de [message].
  MessageExtraction extract(PreparedMessage message) {
    final links = _links(message.original);
    final taken = [for (final link in links) link.span];
    bool free(MessageSpan span) => !taken.any(span.overlaps);

    final ussdCodes = <ExtractedUssdCode>[];
    for (final match in _ussd.allMatches(message.text)) {
      final span = message.folded.toOriginal(match.start, match.end);
      if (!free(span)) continue;
      ussdCodes.add(ExtractedUssdCode(span, match[0]!));
      taken.add(span);
    }

    final amounts = <ExtractedAmount>[];
    for (final pattern in [_amount, _amountPrefix]) {
      for (final match in pattern.allMatches(message.text)) {
        final span = message.folded.toOriginal(match.start, match.end);
        if (!free(span)) continue;
        final digits = match[1]!.replaceAll(RegExp('[^0-9]'), '');
        if (digits.length > 15) continue;
        amounts.add(ExtractedAmount(span, int.parse(digits)));
        taken.add(span);
      }
    }
    amounts.sort((a, b) => a.span.start.compareTo(b.span.start));

    final phones = <ExtractedPhoneNumber>[];
    for (final pattern in [_internationalPhone, _localPhone]) {
      for (final match in pattern.allMatches(message.text)) {
        final span = message.folded.toOriginal(match.start, match.end);
        if (!free(span)) continue;
        final raw = match[0]!;
        var digits = raw.replaceAll(RegExp('[^0-9]'), '');
        if (raw.startsWith('+')) {
          digits = '+$digits';
        } else if (raw.startsWith('00')) {
          digits = '+${digits.substring(2)}';
        }
        phones.add(ExtractedPhoneNumber(span, digits));
        taken.add(span);
      }
    }
    phones.sort((a, b) => a.span.start.compareTo(b.span.start));

    return MessageExtraction(
      links: links,
      phoneNumbers: phones,
      ussdCodes: ussdCodes,
      amounts: amounts,
    );
  }

  List<ExtractedLink> _links(String text) {
    final links = <ExtractedLink>[];
    for (final (pattern, hasScheme) in [
      (_schemeLink, true),
      (_wwwLink, false),
      (_bareLink, false),
    ]) {
      for (final match in pattern.allMatches(text)) {
        var end = match.end;
        // Ponctuation finale : appartient à la phrase, pas au lien.
        while (end > match.start && _trailing.contains(text[end - 1])) {
          final c = text[end - 1];
          if (c == ')' &&
              _count(text, match.start, end, '(') >=
                  _count(text, match.start, end, ')')) {
            break;
          }
          end--;
        }
        if (end < text.length && text[end] == '@') continue; // adresse e-mail
        final span = MessageSpan(match.start, end);
        if (links.any((l) => l.span.overlaps(span))) continue;
        final written = span.of(text);
        final refanged = refang(written);
        final isDefanged = refanged != written;
        if (!hasScheme && !_isLink(refanged)) continue;
        links.add(
          ExtractedLink(
            span: span,
            written: written,
            url: refanged,
            isDefanged: isDefanged,
            hasScheme: hasScheme,
          ),
        );
      }
    }
    links.sort((a, b) => a.span.start.compareTo(b.span.start));
    return links;
  }

  bool _isLink(String candidate) => _parser.parse(candidate) is ParsedUrl;

  static int _count(String text, int start, int end, String char) {
    var count = 0;
    for (var i = start; i < end; i++) {
      if (text[i] == char) count++;
    }
    return count;
  }

  /// Rétablit un lien déguisé : `hxxp` → `http`, `[.]` → `.`, `[://]` →
  /// `://`.
  static String refang(String written) => written
      .replaceAll(_defangedDot, '.')
      .replaceFirst(RegExp(r'^hxxp\[s\]', caseSensitive: false), 'https')
      .replaceFirst(
        RegExp(r'^h(?:xx|\*\*|\[tt\])p', caseSensitive: false),
        'http',
      )
      .replaceFirst('[://]', '://')
      .replaceFirst('[:]//', '://');
}
