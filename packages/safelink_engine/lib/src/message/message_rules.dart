import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/message/message_dictionary.dart';
import 'package:safelink_engine/src/message/message_extraction.dart';
import 'package:safelink_engine/src/message/message_text.dart';
import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/url_parser.dart';

/// Codes stables des indices relevés dans le texte d'un message.
abstract final class MessageSignalCodes {
  /// Demande de transmettre un code, un PIN, un mot de passe.
  static const credentialsRequest = 'MSG_CREDENTIALS_REQUEST';

  /// Demande de saisir un PIN, un mot de passe ou un numéro de carte.
  static const secretEntry = 'MSG_SECRET_ENTRY';

  /// Transfert prétendument fait par erreur, avec demande de restitution.
  static const mistakenTransfer = 'MSG_MISTAKEN_TRANSFER';

  /// Instruction de composer un code USSD de transfert.
  static const ussdTransfer = 'MSG_USSD_TRANSFER';

  /// Paiement ou frais à avancer.
  static const paymentRequest = 'MSG_PAYMENT_REQUEST';

  /// Gain ou cadeau annoncé.
  static const prize = 'MSG_PRIZE';

  /// Menace de blocage ou de suspension.
  static const accountThreat = 'MSG_ACCOUNT_THREAT';

  /// Invitation à poursuivre sur une messagerie privée.
  static const offChannel = 'MSG_OFF_CHANNEL';

  /// Lien qui ne correspond pas à la marque citée.
  static const linkBrandMismatch = 'MSG_LINK_BRAND_MISMATCH';

  /// Sélection ou offre d'emploi inespérée.
  static const selection = 'MSG_SELECTION';

  /// Organisme, marque ou agent cité.
  static const impersonation = 'MSG_IMPERSONATION';

  /// Invitation à appeler un numéro.
  static const callNumber = 'MSG_CALL_NUMBER';

  /// Urgence ou pression.
  static const urgency = 'MSG_URGENCY';

  /// Invitation à agir sur un lien (cliquer, confirmer, réactiver…).
  static const linkAction = 'MSG_LINK_ACTION';

  /// Lien écrit sous une forme déguisée.
  static const defangedLink = 'MSG_DEFANGED_LINK';

  /// Tous les codes, dans l'ordre de `docs/MESSAGE_RULES.md`.
  static const List<String> all = [
    credentialsRequest, secretEntry, mistakenTransfer, ussdTransfer, //
    paymentRequest, prize, accountThreat, offChannel, linkBrandMismatch,
    selection, impersonation, callNumber, linkAction, urgency, defangedLink,
  ];

  /// Catégorie du cahier des charges de chaque code.
  static const Map<String, MessageSignalCategory> categories = {
    credentialsRequest: MessageSignalCategory.credentials,
    secretEntry: MessageSignalCategory.credentials,
    mistakenTransfer: MessageSignalCategory.mistakenTransfer,
    ussdTransfer: MessageSignalCategory.ussdTransfer,
    paymentRequest: MessageSignalCategory.payment,
    prize: MessageSignalCategory.prize,
    selection: MessageSignalCategory.prize,
    accountThreat: MessageSignalCategory.accountThreat,
    offChannel: MessageSignalCategory.offChannel,
    callNumber: MessageSignalCategory.offChannel,
    linkBrandMismatch: MessageSignalCategory.deceptiveLink,
    linkAction: MessageSignalCategory.deceptiveLink,
    defangedLink: MessageSignalCategory.deceptiveLink,
    impersonation: MessageSignalCategory.impersonation,
    urgency: MessageSignalCategory.urgency,
  };
}

/// Indice relevé dans un message, avec les passages à surligner.
@immutable
final class MessageFinding {
  /// Crée un indice.
  new({
    required this.signal,
    required this.category,
    required List<MessageSpan> spans,
    required this.quoted,
  }) : spans = List.unmodifiable(spans);

  /// Indice, avec gravité, confiance, explication et extrait expurgé.
  final RiskSignal signal;

  /// Catégorie du cahier des charges.
  final MessageSignalCategory category;

  /// Passages concernés, en positions du texte d'origine.
  final List<MessageSpan> spans;

  /// Vrai si l'indice n'apparaît que dans un passage cité : sa gravité est
  /// alors abaissée et il ne compte pas dans les combinaisons fortes.
  final bool quoted;

  @override
  String toString() => 'MessageFinding(${signal.code})';
}

/// Masquage des données sensibles dans les extraits d'un message.
abstract final class MessageRedaction {
  /// Remplacement d'un chiffre masqué.
  static const maskedDigit = '•';

  static final _digitRun = RegExp(r'\d(?:[ .\-]?\d){3,}');
  static final _email = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');

  /// [span] de [message], données sensibles masquées : adresses e-mail,
  /// codes et numéros (4 chiffres ou plus, hors montants ; les deux
  /// derniers chiffres d'un numéro long restent visibles).
  static String redact(
    PreparedMessage message,
    MessageExtraction extraction,
    MessageSpan span,
  ) {
    final text = span.of(message.original);
    final buffer = StringBuffer();
    var last = 0;
    for (final match in _digitRun.allMatches(text)) {
      final absolute = MessageSpan(
        span.start + match.start,
        span.start + match.end,
      );
      if (extraction.amounts.any((a) => a.span.overlaps(absolute))) continue;
      buffer.write(text.substring(last, match.start));
      final run = match[0]!;
      final digits = run.replaceAll(RegExp('[^0-9]'), '').length;
      final keep = digits >= 8 ? 2 : 0;
      var seen = 0;
      for (final char in run.split('')) {
        if (RegExp('[0-9]').hasMatch(char)) {
          seen++;
          buffer.write(seen > digits - keep ? char : maskedDigit);
        } else {
          buffer.write(char);
        }
      }
      last = match.end;
    }
    buffer.write(text.substring(last));
    return buffer.toString().replaceAll(_email, '•••@•••');
  }
}

/// Règles déterministes appliquées au texte d'un message.
///
/// Aucun mot isolé ne vaut preuve : chaque règle exige une construction
/// (verbe + objet, paiement + but, menace + sujet) et écarte les
/// tournures niées. Les passages cités comptent moins.
final class MessageRules {
  /// Crée les règles.
  new({
    MessageDictionary? dictionary,
    BrandMatcher? brandMatcher,
    UrlParser? parser,
  }) : dictionary = dictionary ?? MessageDictionary.french,
       brandMatcher = brandMatcher ?? BrandMatcher(),
       _parser = parser ?? UrlParser() {
    final d = this.dictionary;
    _credentials = [
      RegExp(
        '(?<![a-z])${d.transmissionVerbs}(?![a-z])[^.!?\\n]{0,60}?'
        '(?<![a-z])${d.secrets}(?![a-z])',
      ),
      RegExp(
        '(?<![a-z])${d.secrets}(?![a-z])[^.!?\\n]{0,60}?(?<![a-z])'
        '${d.transmissionVerbs}[- ](?:le|la|les|nous|moi|lui|leur)(?![a-z])',
      ),
    ];
    _secretEntry = RegExp(
      '(?<![a-z])${d.entryVerbs}(?![a-z])[^.!?\\n]{0,40}?'
      '(?<![a-z])${d.strongSecrets}(?![a-z])',
    );
    _paymentVerb = RegExp('(?<![a-z])${d.paymentVerbs}(?![a-z])');
    _paymentPurpose = RegExp(
      '(?<![a-z])pour (?:les? |la )?${d.paymentPurposes}',
    );
    _scamFees = RegExp('(?<![a-z])${d.scamFees}(?![a-z])');
    _ordinaryFees = RegExp('(?<![a-z])${d.ordinaryFees}(?![a-z])');
    _offChannel = RegExp(
      '(?<![a-z])${d.contactVerbs}(?![a-z])[^.!?\\n]{0,40}?'
      '(?<![a-z])${d.messagingApps}(?![a-z])',
    );
    _contact = RegExp('(?<![a-z])${d.contactVerbs}(?![a-z])');
    _returnRequest = RegExp('(?<![a-z])${d.returnRequests}(?![a-z])');
    _dial = RegExp('(?<![a-z])${d.dialVerbs}(?![a-z])');
    _linkAction = RegExp('(?<![a-z])${d.linkActionVerbs}(?![a-z])');
  }

  /// Dictionnaire utilisé.
  final MessageDictionary dictionary;

  /// Marques de référence, pour les organismes cités et les liens.
  final BrandMatcher brandMatcher;

  final UrlParser _parser;

  late final List<RegExp> _credentials;
  late final RegExp _secretEntry;
  late final RegExp _paymentVerb;
  late final RegExp _paymentPurpose;
  late final RegExp _scamFees;
  late final RegExp _ordinaryFees;
  late final RegExp _offChannel;
  late final RegExp _contact;
  late final RegExp _returnRequest;
  late final RegExp _dial;
  late final RegExp _linkAction;

  /// Phrases qui décrivent une arnaque au lieu d'en commettre une.
  static final _warningContext = RegExp(
    r'(?<![a-z])(?:arnaque\w*|escroc\w*|fraude\w*|fraudeur\w*|attention|'
    r'mefie\w*|prudence|vigilan\w*|jamais)(?![a-z])',
  );

  /// Pronoms qui s'adressent au destinataire.
  static final _addressee = RegExp(
    '(?<![a-z])(?:vous|votre|vos|tu|ton|ta|tes|toi)(?![a-z])',
  );

  static final _noFees = RegExp(
    '(?<![a-z])(?:sans|aucun|aucuns|pas de|zero) (?:frais|taxes?|caution)',
  );

  /// Verbes qui désignent toujours un paiement.
  static final _inherentlyMonetary = RegExp(
    '^(?:pay|regl|vers|depos|faites|faire)',
  );

  /// Mots qui désignent de l'argent.
  static final _moneyWords = RegExp(
    '(?<![a-z])(?:argent|frais|somme|montant|credit|unites|recharge|'
    'mobile money|orange money|moov money|wave|fcfa|cfa|depot|paiement|'
    'transfert|caution|avance)(?![a-z])',
  );

  /// Tournures hypothétiques : « si quelqu'un vous demande… ».
  static final _hypothetical = RegExp(
    "(?<![a-z])(?:si|s'il|s'ils|quand|lorsque|lorsqu)(?![a-z])",
  );

  /// Indices relevés dans [message].
  List<MessageFinding> evaluate(
    PreparedMessage message,
    MessageExtraction extraction,
    DateTime now,
  ) {
    final context = _Context(message, extraction, now);

    _credentialsRules(context);
    _mistakenTransfer(context);
    _ussd(context);
    _payment(context);
    _patterns(
      context,
      dictionary.prizes,
      MessageSignalCodes.prize,
      Severity.medium,
      Confidence.medium,
      'Le message annonce un gain ou un cadeau inattendu, procédé courant '
      'pour obtenir de l’argent ou des codes.',
    );
    _patterns(
      context,
      dictionary.accountThreats,
      MessageSignalCodes.accountThreat,
      Severity.medium,
      Confidence.medium,
      'Le message menace de bloquer ou de suspendre un compte, une carte ou '
      'une ligne pour pousser à agir vite.',
    );
    _offChannelRules(context);
    _linkRules(context);
    _patterns(
      context,
      dictionary.selections,
      MessageSignalCodes.selection,
      Severity.low,
      Confidence.low,
      'Le message annonce une sélection ou une offre d’emploi ; une offre '
      'sérieuse ne demande jamais de payer pour en bénéficier.',
    );
    _impersonation(context);
    _patterns(
      context,
      dictionary.urgencies,
      MessageSignalCodes.urgency,
      Severity.low,
      Confidence.low,
      'Le message presse d’agir vite. L’urgence seule ne prouve rien, mais '
      'elle accompagne souvent les arnaques.',
    );

    final findings = context.build();
    const order = MessageSignalCodes.all;
    findings.sort((a, b) {
      final bySeverity = b.signal.severity.index.compareTo(
        a.signal.severity.index,
      );
      return bySeverity != 0
          ? bySeverity
          : order
                .indexOf(a.signal.code)
                .compareTo(order.indexOf(b.signal.code));
    });
    return findings;
  }

  void _credentialsRules(_Context c) {
    for (final pattern in _credentials) {
      for (final match in pattern.allMatches(c.text)) {
        final span = MessageSpan(match.start, match.end);
        if (c.message.isNegated(span)) continue;
        final phrase = match[0]!;
        // « demander » décrit souvent une arnaque (« si quelqu'un vous
        // demande votre code ») : il ne compte que hors mise en garde.
        if (phrase.startsWith('demand') && c.isWarningOrHypothetical(span)) {
          continue;
        }
        c.add(
          MessageSignalCodes.credentialsRequest,
          Severity.high,
          Confidence.high,
          'Le message demande de transmettre un code, un PIN ou un mot de '
          'passe. Aucun service sérieux ne le demande : ces codes '
          'donnent accès à votre argent ou à vos comptes.',
          span,
        );
      }
    }
    for (final match in _secretEntry.allMatches(c.text)) {
      final span = MessageSpan(match.start, match.end);
      if (c.message.isNegated(span)) continue;
      c.add(
        MessageSignalCodes.secretEntry,
        Severity.high,
        Confidence.medium,
        'Le message demande de saisir un code secret, un mot de passe ou un '
        'numéro de carte, ce qu’aucun service ne fait demander par '
        'message.',
        span,
      );
    }
  }

  void _mistakenTransfer(_Context c) {
    for (final pattern in dictionary.mistakenTransfers) {
      for (final match in pattern.regex.allMatches(c.text)) {
        final span = MessageSpan(match.start, match.end);
        // « Des escrocs prétendent que… » : une mise en garde, pas une
        // demande.
        if (c.message.isNegated(span) || c.isWarning(span)) continue;
        final asksReturn = _returnRequest
            .allMatches(c.text, match.end)
            .any((r) => !c.message.isNegated(MessageSpan(r.start, r.end)));
        c.add(
          MessageSignalCodes.mistakenTransfer,
          asksReturn ? Severity.high : Severity.medium,
          asksReturn ? Confidence.high : Confidence.medium,
          asksReturn
              ? 'Le message parle d’un transfert fait « par erreur » et '
                    'demande de le renvoyer : arnaque très répandue. Vérifiez '
                    'votre solde dans l’application officielle avant tout.'
              : 'Le message parle d’un transfert fait « par erreur ». '
                    'Vérifiez votre solde dans l’application officielle.',
          span,
        );
      }
    }
  }

  void _ussd(_Context c) {
    for (final code in c.extraction.ussdCodes) {
      if (!code.carriesTransferData) continue;
      final foldedStart = c.message.folded.toFolded(code.span.start);
      final sentence = c.message.sentenceAt(foldedStart);
      final before = c.text.substring(sentence.start, foldedStart);
      final instructed = _dial.hasMatch(before);
      final span = MessageSpan(
        foldedStart,
        c.message.folded.toFolded(code.span.end),
      );
      c.add(
        MessageSignalCodes.ussdTransfer,
        instructed ? Severity.high : Severity.medium,
        instructed ? Confidence.high : Confidence.medium,
        'Le message contient un code USSD qui inclut un numéro ou un '
        'montant : le composer peut envoyer de l’argent depuis votre '
        'compte.',
        span,
      );
    }
  }

  void _payment(_Context c) {
    for (final sentence in c.message.sentences) {
      // « Livraison sans frais » : les frais sont écartés, pas demandés.
      final text = sentence
          .of(c.text)
          .replaceAllMapped(_noFees, (m) => ' ' * m[0]!.length);
      final verb = _paymentVerb.firstMatch(text);
      final fees = _scamFees.firstMatch(text);
      final original = c.message.folded.toOriginal(
        sentence.start,
        sentence.end,
      );
      final hasAmount = c.extraction.amounts.any(
        (a) => original.contains(a.span),
      );
      final hasPhone = c.extraction.phoneNumbers.any(
        (p) => original.contains(p.span),
      );
      MessageSpan? span;
      if (verb != null) {
        final verbSpan = MessageSpan(
          sentence.start + verb.start,
          sentence.start + verb.end,
        );
        // Négation cherchée autour du verbe seulement : « payez, sinon vous
        // ne recevrez rien » reste une demande.
        final negated = c.message.isNegated(
          MessageSpan(
            verbSpan.start,
            (verbSpan.end + 15).clamp(verbSpan.end, sentence.end),
          ),
        );
        final money =
            hasAmount ||
            _inherentlyMonetary.hasMatch(verb[0]!) ||
            _moneyWords.hasMatch(text);
        final purpose = _paymentPurpose.hasMatch(text);
        final threat = dictionary.accountThreats.any(
          (p) => p.regex.hasMatch(text),
        );
        if (!negated &&
            money &&
            (fees != null || purpose || hasPhone || (hasAmount && threat))) {
          span = MessageSpan(verbSpan.start, sentence.end);
        }
      }
      var ordinary = false;
      if (span == null &&
          verb != null &&
          hasAmount &&
          _ordinaryFees.hasMatch(text) &&
          !c.message.isNegated(
            MessageSpan(
              sentence.start + verb.start,
              (sentence.start + verb.end + 15).clamp(0, sentence.end),
            ),
          )) {
        span = MessageSpan(sentence.start, sentence.end);
        ordinary = true;
      }
      if (span == null && fees != null && hasAmount) {
        final feeSpan = MessageSpan(
          sentence.start + fees.start,
          sentence.start + fees.end,
        );
        if (!c.message.isNegated(feeSpan)) {
          span = MessageSpan(sentence.start, sentence.end);
        }
      }
      if (span == null) continue;
      c.add(
        MessageSignalCodes.paymentRequest,
        ordinary ? Severity.low : Severity.medium,
        ordinary ? Confidence.low : Confidence.medium,
        ordinary
            ? 'Le message demande un paiement. Payez seulement par les canaux '
                  'officiels, après avoir vérifié la demande.'
            : 'Le message demande de payer ou d’envoyer de l’argent pour '
                  'recevoir ou débloquer quelque chose : c’est le principe des '
                  'arnaques aux frais anticipés.',
        _trim(c.text, span),
      );
    }
  }

  void _offChannelRules(_Context c) {
    for (final match in _offChannel.allMatches(c.text)) {
      final span = MessageSpan(match.start, match.end);
      if (c.message.isNegated(span)) continue;
      c.add(
        MessageSignalCodes.offChannel,
        Severity.medium,
        Confidence.medium,
        'Le message invite à poursuivre sur une messagerie privée, hors des '
        'canaux officiels, où personne ne peut vérifier l’interlocuteur.',
        span,
      );
    }
    for (final phone in c.extraction.phoneNumbers) {
      final foldedStart = c.message.folded.toFolded(phone.span.start);
      final sentence = c.message.sentenceAt(foldedStart);
      final before = c.text.substring(sentence.start, foldedStart);
      final contact = _contact.allMatches(before).lastOrNull;
      if (contact == null) continue;
      final span = MessageSpan(
        sentence.start + contact.start,
        c.message.folded.toFolded(phone.span.end),
      );
      if (c.message.isNegated(span)) continue;
      c.add(
        MessageSignalCodes.callNumber,
        Severity.low,
        Confidence.low,
        'Le message invite à appeler ou contacter un numéro. Utilisez plutôt '
        'le numéro officiel que vous connaissez déjà.',
        span,
      );
    }
  }

  void _linkRules(_Context c) {
    final linkSpans = [
      for (final link in c.extraction.links)
        MessageSpan(
          c.message.folded.toFolded(link.span.start),
          c.message.folded.toFolded(link.span.end),
        ),
    ];
    for (final (i, link) in c.extraction.links.indexed) {
      if (link.isDefanged) {
        c.add(
          MessageSignalCodes.defangedLink,
          Severity.info,
          Confidence.high,
          'Un lien est écrit sous une forme déguisée (hxxp, [.]…). Les '
          'messages de mise en garde le font pour le neutraliser ; '
          'SafeLink l’analyse sous sa forme réelle.',
          linkSpans[i],
        );
      }
    }
    for (final (i, link) in c.extraction.links.indexed) {
      if (link.isDefanged) continue;
      final sentence = c.message.sentenceAt(linkSpans[i].start);
      final before = c.text.substring(sentence.start, linkSpans[i].start);
      final action = _linkAction.allMatches(before).lastOrNull;
      if (action == null) continue;
      final span = MessageSpan(sentence.start + action.start, linkSpans[i].end);
      if (c.message.isNegated(span)) continue;
      c.add(
        MessageSignalCodes.linkAction,
        Severity.low,
        Confidence.low,
        'Le message demande d’agir sur un lien (cliquer, confirmer, '
        'réactiver…). Passez plutôt par l’application ou le site officiel '
        'que vous connaissez.',
        span,
      );
    }
    final textWithoutLinks = StringBuffer();
    var last = 0;
    for (final span in linkSpans) {
      textWithoutLinks
        ..write(c.text.substring(last, span.start))
        ..write(' ');
      last = span.end;
    }
    textWithoutLinks.write(c.text.substring(last));
    final cited = brandMatcher.brandsMentionedIn(textWithoutLinks.toString());
    if (cited.isEmpty) return;
    for (final (i, link) in c.extraction.links.indexed) {
      // Un lien déguisé ne se clique pas : il vient d'une mise en garde.
      if (link.isDefanged) continue;
      final parsed = _parser.parse(link.url);
      if (parsed is! ParsedUrl) continue;
      final registrable = parsed.registrableDomain ?? parsed.host;
      if (cited.any((brand) => brand.domains.contains(registrable))) continue;
      final names = (cited.map((b) => b.name).toList()..sort()).join(', ');
      c.add(
        MessageSignalCodes.linkBrandMismatch,
        Severity.medium,
        Confidence.medium,
        'Le message cite $names, mais le lien mène à $registrable, qui '
        'n’est pas un domaine officiel connu de SafeLink pour cette '
        'marque.',
        linkSpans[i],
      );
    }
  }

  void _impersonation(_Context c) {
    final names = <String>{
      for (final brand in brandMatcher.brandsMentionedIn(c.text)) brand.name,
    };
    MessageSpan? first;
    for (final pattern in dictionary.impersonations) {
      final match = pattern.regex.firstMatch(c.text);
      if (match == null) continue;
      final span = MessageSpan(match.start, match.end);
      if (first == null || span.start < first.start) first = span;
    }
    if (first == null && names.isEmpty) return;
    final cited = names.isEmpty
        ? 'un organisme'
        : (names.toList()..sort()).join(', ');
    c.add(
      MessageSignalCodes.impersonation,
      Severity.low,
      Confidence.low,
      'Le message se présente comme venant de $cited. Ce nom n’est pas une '
      'preuve : n’importe qui peut l’écrire.',
      first ?? _firstBrandSpan(c, names),
    );
  }

  MessageSpan _firstBrandSpan(_Context c, Set<String> names) {
    for (final sentence in c.message.sentences) {
      final mentioned = brandMatcher.brandsMentionedIn(sentence.of(c.text));
      if (mentioned.isNotEmpty) return sentence;
    }
    return MessageSpan(0, c.text.length);
  }

  void _patterns(
    _Context c,
    List<PhrasePattern> patterns,
    String code,
    Severity severity,
    Confidence confidence,
    String reason,
  ) {
    for (final pattern in patterns) {
      for (final match in pattern.regex.allMatches(c.text)) {
        final span = MessageSpan(match.start, match.end);
        if (c.message.isNegated(span)) continue;
        if (pattern.addressed &&
            !_addressee.hasMatch(c.message.sentenceAt(span.start).of(c.text))) {
          continue;
        }
        c.add(code, severity, confidence, reason, span);
      }
    }
  }

  static MessageSpan _trim(String text, MessageSpan span) {
    var start = span.start;
    var end = span.end;
    while (start < end && ' \n\t'.contains(text[start])) {
      start++;
    }
    while (end > start && ' \n\t'.contains(text[end - 1])) {
      end--;
    }
    return MessageSpan(start, end);
  }
}

/// Occurrence d'un indice.
typedef _Occurrence = ({
  Severity severity,
  Confidence confidence,
  String reason,
  MessageSpan span,
  bool quoted,
});

/// État d'une évaluation : regroupe les occurrences par code.
final class _Context {
  new(this.message, this.extraction, this.now);

  final PreparedMessage message;
  final MessageExtraction extraction;
  final DateTime now;

  final Map<String, List<_Occurrence>> _occurrences = {};

  String get text => message.text;

  bool isWarning(MessageSpan span) => MessageRules._warningContext.hasMatch(
    message.sentenceAt(span.start).of(text),
  );

  bool isWarningOrHypothetical(MessageSpan span) {
    final sentence = message.sentenceAt(span.start);
    final clause = text.substring(message.clauseStart(span.start), span.end);
    return MessageRules._warningContext.hasMatch(sentence.of(text)) ||
        MessageRules._hypothetical.hasMatch(clause);
  }

  /// Ajoute une occurrence de [code] au passage replié [foldedSpan].
  void add(
    String code,
    Severity severity,
    Confidence confidence,
    String reason,
    MessageSpan foldedSpan,
  ) {
    (_occurrences[code] ??= []).add((
      severity: severity,
      confidence: confidence,
      reason: reason,
      span: message.folded.toOriginal(foldedSpan.start, foldedSpan.end),
      quoted: message.isQuoted(foldedSpan),
    ));
  }

  /// Un indice par code : l'occurrence hors citation la plus grave fixe la
  /// gravité et l'extrait ; tous les passages sont gardés pour le
  /// surlignage.
  List<MessageFinding> build() => [
    for (final MapEntry(key: code, value: occurrences) in _occurrences.entries)
      _finding(code, occurrences),
  ];

  MessageFinding _finding(String code, List<_Occurrence> occurrences) {
    final best = occurrences.reduce((a, b) {
      if (a.quoted != b.quoted) return a.quoted ? b : a;
      return b.severity.index > a.severity.index ? b : a;
    });
    final quoted = best.quoted;
    var evidence = MessageRedaction.redact(
      message,
      extraction,
      best.span,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (evidence.length > RiskSignal.maxEvidenceLength) {
      evidence = '${evidence.substring(0, RiskSignal.maxEvidenceLength - 1)}…';
    }
    return MessageFinding(
      signal: RiskSignal(
        code: code,
        severity: quoted && best.severity != Severity.info
            ? Severity.low
            : best.severity,
        confidence: quoted ? Confidence.low : best.confidence,
        reason: quoted
            ? '${best.reason} Ce passage est cité : il compte moins.'
            : best.reason,
        source: SignalSource.messageRule,
        detectedAt: now,
        evidence: evidence.isEmpty ? null : evidence,
      ),
      category: MessageSignalCodes.categories[code]!,
      spans: [for (final o in occurrences) o.span],
      quoted: quoted,
    );
  }
}
