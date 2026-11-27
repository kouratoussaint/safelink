import 'package:safelink_engine/src/common/analysis.dart';
import 'package:safelink_engine/src/common/content_type.dart';
import 'package:safelink_engine/src/common/notes.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/common/verdicts.dart';
import 'package:safelink_engine/src/message/message_dictionary.dart';
import 'package:safelink_engine/src/message/message_extraction.dart';
import 'package:safelink_engine/src/message/message_rules.dart';
import 'package:safelink_engine/src/message/message_text.dart';

/// Résultat de l'analyse du texte d'un message (les liens qu'il contient
/// sont analysés à part, voir `CombinedAnalyzer`).
final class MessageAnalysisResult extends AnalysisResult {
  /// Crée un résultat ; utilisé par [MessageAnalyzer].
  new({
    required this.verdict,
    required this.confidence,
    required List<MessageFinding> findings,
    required super.limitations,
    required super.recommendedActions,
    required super.analyzedAt,
    required super.rulesVersion,
    this.extraction,
  }) : findings = List.unmodifiable(findings),
       super(
         contentType: ContentType.message,
         signals: [for (final f in findings) f.signal],
         processing: Processing.localOnly,
         privacyImpact: PrivacyImpact.stayedOnDevice,
       );

  /// Verdict normatif.
  final MessageVerdict verdict;

  /// Confiance dans le verdict.
  final Confidence confidence;

  /// Indices, avec les passages à surligner.
  final List<MessageFinding> findings;

  /// Liens, numéros, codes USSD et montants repérés ; absent si le message
  /// n'a pas pu être analysé.
  final MessageExtraction? extraction;

  @override
  RiskLevel get level => verdict.level;
}

/// Règles de décision du verdict d'un message.
///
/// - `HIGH_RISK_MESSAGE` : un indice fort (demande de code, saisie d'un
///   secret, transfert « par erreur » à renvoyer, code USSD de transfert),
///   ou une demande de paiement associée à un gain, un organisme cité, une
///   urgence ou une menace de blocage.
/// - `SUSPICIOUS_MESSAGE` : un indice moyen, ou deux indices faibles (le
///   seul fait de citer un organisme ne compte pas : presque tous les
///   messages légitimes le font).
/// - `NO_OBVIOUS_SIGNALS` : texte en français, assez long, sans indice.
/// - `INCONCLUSIVE_MESSAGE` : texte trop court ou majoritairement dans une
///   langue non prise en charge, sans indice.
///
/// Les indices relevés seulement dans un passage cité ne comptent que
/// comme indices faibles.
final class MessageVerdictPolicy {
  /// Crée une politique.
  const new({
    this.minWords = 3,
    this.minWordsForLanguage = 5,
    this.minFrenchRatio = 0.2,
  });

  /// Nombre minimal de mots pour conclure à l'absence d'indice.
  final int minWords;

  /// Nombre de mots à partir duquel la langue est évaluée.
  final int minWordsForLanguage;

  /// Part minimale de mots-outils français.
  final double minFrenchRatio;

  /// Catégories qui, avec un paiement, font un message à haut risque.
  static const Set<MessageSignalCategory> paymentAggravators = {
    MessageSignalCategory.prize,
    MessageSignalCategory.impersonation,
    MessageSignalCategory.urgency,
    MessageSignalCategory.accountThreat,
  };

  /// Verdict et confiance.
  (MessageVerdict, Confidence) decide(
    List<MessageFinding> findings,
    LanguageAssessment language,
  ) {
    final direct = findings.where((f) => !f.quoted).toList();
    final strong = direct.where((f) => f.signal.severity == Severity.high);
    final payment = direct.any(
      (f) => f.category == MessageSignalCategory.payment,
    );
    final aggravated =
        payment && direct.any((f) => paymentAggravators.contains(f.category));
    if (strong.isNotEmpty || aggravated) {
      final confident = strong.any(
        (f) => f.signal.confidence == Confidence.high,
      );
      return (
        MessageVerdict.highRiskMessage,
        confident ? Confidence.high : Confidence.medium,
      );
    }

    final medium = findings.where((f) => f.signal.severity == Severity.medium);
    final low = findings.where(
      (f) =>
          f.signal.severity == Severity.low &&
          f.category != MessageSignalCategory.impersonation,
    );
    if (medium.isNotEmpty || low.length >= 2) {
      return (
        MessageVerdict.suspiciousMessage,
        medium.length >= 2 ? Confidence.medium : Confidence.low,
      );
    }

    if (!_isAnalyzable(language)) {
      return (MessageVerdict.inconclusiveMessage, Confidence.low);
    }
    return (MessageVerdict.noObviousSignals, Confidence.low);
  }

  bool _isAnalyzable(LanguageAssessment language) =>
      isLongEnough(language) && isSupportedLanguage(language);

  /// Vrai si le texte compte assez de mots.
  bool isLongEnough(LanguageAssessment language) =>
      language.wordCount >= minWords;

  /// Vrai si le texte semble rédigé en français (ou trop court pour en
  /// juger).
  bool isSupportedLanguage(LanguageAssessment language) =>
      language.wordCount < minWordsForLanguage ||
      language.frenchRatio >= minFrenchRatio;
}

/// Analyse locale du texte d'un message : préparation, extraction, indices,
/// verdict prudent, limites et gestes recommandés.
final class MessageAnalyzer
    implements ContentAnalyzer<String, MessageAnalysisResult> {
  /// Crée un analyseur. [maxLength] borne la taille d'un message, en
  /// caractères.
  new({
    this.maxLength = defaultMaxLength,
    MessageRules? rules,
    MessageExtractor? extractor,
    this.policy = const MessageVerdictPolicy(),
  }) : rules = rules ?? MessageRules(),
       extractor = extractor ?? MessageExtractor() {
    if (maxLength < 1) {
      throw ArgumentError.value(maxLength, 'maxLength', 'doit être positif');
    }
  }

  /// Taille maximale par défaut d'un message.
  static const defaultMaxLength = 10000;

  /// Version des règles d'analyse des messages.
  static const rulesVersion = 'message-1.0.0';

  /// Taille maximale acceptée, en caractères.
  final int maxLength;

  /// Règles de signaux.
  final MessageRules rules;

  /// Extracteur des liens, numéros, codes et montants.
  final MessageExtractor extractor;

  /// Règles de décision du verdict.
  final MessageVerdictPolicy policy;

  @override
  ContentType get contentType => ContentType.message;

  /// Version complète : règles et dictionnaire.
  String get fullRulesVersion =>
      '$rulesVersion+dico.${rules.dictionary.version}';

  @override
  MessageAnalysisResult analyze(String input, AnalysisContext context) {
    final now = context.now();
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed.runes.length > maxLength) {
      final tooLong = trimmed.isNotEmpty;
      return MessageAnalysisResult(
        verdict: MessageVerdict.invalidMessage,
        confidence: Confidence.high,
        findings: const [],
        limitations: [
          Limitation(
            code: tooLong ? 'MESSAGE_TOO_LONG' : 'MESSAGE_EMPTY',
            description: tooLong
                ? 'Le message dépasse $maxLength caractères : il n’a pas été '
                      'analysé. Collez seulement la partie utile.'
                : 'Aucun texte à analyser.',
          ),
        ],
        recommendedActions: [
          RecommendedAction(
            code: 'PASTE_MESSAGE',
            description:
                'Collez le texte du message reçu, tel quel, pour l’analyser.',
          ),
        ],
        analyzedAt: now,
        rulesVersion: fullRulesVersion,
      );
    }

    final prepared = MessagePreprocessor.prepare(input);
    final extraction = extractor.extract(prepared);
    final findings = rules.evaluate(prepared, extraction, now);
    final language = _languageWithoutLinks(input, extraction);
    final (verdict, confidence) = policy.decide(findings, language);
    return MessageAnalysisResult(
      verdict: verdict,
      confidence: confidence,
      findings: findings,
      extraction: extraction,
      limitations: _limitations(language, extraction),
      recommendedActions: recommendedActionsFor(verdict, findings),
      analyzedAt: now,
      rulesVersion: fullRulesVersion,
    );
  }

  /// Langue évaluée sans les liens, qui ne sont pas du texte.
  static LanguageAssessment _languageWithoutLinks(
    String input,
    MessageExtraction extraction,
  ) {
    final buffer = StringBuffer();
    var last = 0;
    for (final link in extraction.links) {
      buffer
        ..write(input.substring(last, link.span.start))
        ..write(' ');
      last = link.span.end;
    }
    buffer.write(input.substring(last));
    return MessagePreprocessor.assessLanguage(
      FoldedText(buffer.toString()).text,
    );
  }

  List<Limitation> _limitations(
    LanguageAssessment language,
    MessageExtraction extraction,
  ) => [
    Limitation(
      code: 'SENDER_NOT_VERIFIED',
      description:
          'SafeLink ne peut pas vérifier qui a envoyé ce message ni si son '
          'contenu est vrai.',
    ),
    Limitation(
      code: 'TEXT_RULES_LIMITS',
      description:
          'Les règles locales repèrent des procédés d’arnaque courants ; une '
          'arnaque nouvelle peut n’en présenter aucun.',
    ),
    if (!policy.isLongEnough(language))
      Limitation(
        code: 'MESSAGE_TOO_SHORT',
        description: 'Le texte est trop court pour en juger.',
      ),
    if (!policy.isSupportedLanguage(language))
      Limitation(
        code: 'LANGUAGE_NOT_SUPPORTED',
        description:
            'Le message semble écrit dans une autre langue que le français : '
            'les règles ne le comprennent pas.',
      ),
    if (extraction.links.isNotEmpty)
      Limitation(
        code: 'LINKS_ANALYZED_SEPARATELY',
        description:
            'Les liens du message sont analysés à part ; leur résultat peut '
            'différer de celui du texte.',
      ),
  ];

  /// Gestes recommandés, adaptés au [verdict] et aux catégories relevées.
  static List<RecommendedAction> recommendedActionsFor(
    MessageVerdict verdict,
    List<MessageFinding> findings,
  ) {
    final categories = {
      for (final f in findings)
        if (!f.quoted && f.signal.severity.rank >= Severity.low.rank)
          f.category,
    };
    RecommendedAction action(String code, String description) =>
        RecommendedAction(code: code, description: description);
    final risky =
        verdict == MessageVerdict.highRiskMessage ||
        verdict == MessageVerdict.suspiciousMessage;
    return [
      if (categories.contains(MessageSignalCategory.credentials) || risky)
        action(
          'NEVER_SHARE_CODES',
          'Ne communiquez aucun code reçu par SMS, code secret ou mot de '
              'passe, même à quelqu’un qui se présente comme un agent.',
        ),
      if (categories.contains(MessageSignalCategory.ussdTransfer))
        action(
          'DO_NOT_DIAL',
          'Ne composez pas le code indiqué dans le message.',
        ),
      if (categories.contains(MessageSignalCategory.mistakenTransfer))
        action(
          'CHECK_BALANCE_OFFICIAL',
          'Vérifiez votre solde dans l’application ou par le code officiel '
              'de votre opérateur. Ne renvoyez rien vous-même : un vrai '
              'transfert par erreur se règle avec l’opérateur.',
        ),
      if (categories.contains(MessageSignalCategory.payment) ||
          categories.contains(MessageSignalCategory.prize))
        action(
          'DO_NOT_PAY',
          'Ne payez rien et n’envoyez pas d’argent à la demande d’un contact '
              'que vous n’avez pas vérifié. Un vrai gain ne demande pas de '
              'frais.',
        ),
      if (categories.contains(MessageSignalCategory.offChannel))
        action(
          'STAY_ON_OFFICIAL_CHANNELS',
          'Restez sur les canaux officiels : ne poursuivez pas l’échange sur '
              'une messagerie privée ou par un numéro donné dans le message.',
        ),
      action(
        'VERIFY_OFFICIAL_CHANNEL',
        'En cas de doute, contactez l’organisme par son application ou le '
            'numéro officiel que vous connaissez déjà, jamais par les '
            'coordonnées du message.',
      ),
      if (risky)
        action(
          'REPORT_AND_BLOCK',
          'Signalez le message à votre opérateur ou à la plateforme '
              'concernée, puis bloquez l’expéditeur.',
        )
      else
        action(
          'STAY_ALERT',
          'Restez vigilant : un message sans indice repéré peut quand même '
              'être une arnaque.',
        ),
    ];
  }
}
