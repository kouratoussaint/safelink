import 'dart:io';

import 'package:safelink_engine/safelink_engine.dart';
import 'package:safelink_engine/src/evaluation/message_corpus.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 9);
  final context = AnalysisContext(clock: () => now);
  final analyzer = MessageAnalyzer();

  MessageVerdict verdictOf(String text) =>
      analyzer.analyze(text, context).verdict;

  group('cas incontournables du cahier des charges', () {
    test('texte légitime', () {
      expect(
        verdictOf('Bonjour, la réunion de parents aura lieu samedi à 9 h.'),
        MessageVerdict.noObviousSignals,
      );
    });

    test('fausse urgence', () {
      expect(
        verdictOf(
          'URGENT : votre compte sera bloqué ce soir, appelez le 70 00 99 88.',
        ),
        MessageVerdict.suspiciousMessage,
      );
    });

    test('demande d’OTP ou de PIN', () {
      expect(
        verdictOf('Envoyez-moi le code reçu par SMS pour valider le bonus.'),
        MessageVerdict.highRiskMessage,
      );
      expect(
        verdictOf('Votre code est 482913. Ne le communiquez à personne.'),
        MessageVerdict.noObviousSignals,
      );
    });

    test('fausse loterie', () {
      expect(
        verdictOf(
          'Vous avez gagné 500 000 F ! Payez 5 000 F de frais de dossier.',
        ),
        MessageVerdict.highRiskMessage,
      );
    });

    test('faux recrutement demandant un paiement', () {
      expect(
        verdictOf(
          'Vous avez été retenu pour le poste. Les frais de formation de '
          '20 000 F sont à payer avant lundi.',
        ),
        MessageVerdict.highRiskMessage,
      );
    });

    test('message sans lien, avec un ou plusieurs liens', () {
      final none = analyzer.analyze('Rendez-vous demain à 8 h.', context);
      expect(none.extraction!.links, isEmpty);
      final several = analyzer.analyze(
        'Voir www.orange.bf et lefaso.net puis https://bit.ly/abc',
        context,
      );
      expect(several.extraction!.links, hasLength(3));
      expect(
        several.limitations.map((l) => l.code),
        contains('LINKS_ANALYZED_SEPARATELY'),
      );
    });

    test('lien déguisé', () {
      final result = analyzer.analyze(
        'Attention au lien hxxp://faux-orange[.]top qui circule.',
        context,
      );
      expect(result.extraction!.links.single.isDefanged, isTrue);
      expect(
        result.signals.map((s) => s.code),
        contains(MessageSignalCodes.defangedLink),
      );
    });

    test('texte très long : 10 000 caractères analysés dans le budget', () {
      final text = decodeCorpusText('<long:10000>');
      final stopwatch = Stopwatch()..start();
      final result = analyzer.analyze(text, context);
      stopwatch.stop();
      expect(result.verdict, isNot(MessageVerdict.invalidMessage));
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 1500)));
      expect(
        verdictOf(decodeCorpusText('<long:10001>')),
        MessageVerdict.invalidMessage,
      );
    });

    test('Unicode et émojis', () {
      expect(
        verdictOf(
          '🎉🎉 Félicitations !!! Vous avez gagné 1 moto 🏍\uFE0F ! '
          'Payez 2 000 F de frais d’activation 💰',
        ),
        MessageVerdict.highRiskMessage,
      );
      expect(verdictOf('😀👍'), MessageVerdict.inconclusiveMessage);
    });

    test('négations, citations et signaux ambigus', () {
      expect(
        verdictOf('Ne communiquez jamais votre code, même à un agent.'),
        MessageVerdict.noObviousSignals,
      );
      expect(
        verdictOf('Ils disent « envoyez votre code PIN ». C’est faux.'),
        MessageVerdict.noObviousSignals,
      );
      expect(
        verdictOf('C’est urgent, rappelle-moi.'),
        MessageVerdict.noObviousSignals,
      );
    });
  });

  group('verdicts et limites', () {
    test('vide ou trop long : non analysable', () {
      for (final text in ['', '   \n ']) {
        final result = analyzer.analyze(text, context);
        expect(result.verdict, MessageVerdict.invalidMessage);
        expect(result.level, RiskLevel.notAnalyzable);
        expect(result.limitations.single.code, 'MESSAGE_EMPTY');
        expect(result.extraction, isNull);
        expect(result.recommendedActions.single.code, 'PASTE_MESSAGE');
      }
      final small = MessageAnalyzer(maxLength: 10);
      expect(small.maxLength, 10);
      expect(
        small.analyze('Bonjour à tous !', context).limitations.single.code,
        'MESSAGE_TOO_LONG',
      );
      expect(() => MessageAnalyzer(maxLength: 0), throwsArgumentError);
    });

    test('trop court ou autre langue : analyse insuffisante', () {
      final short = analyzer.analyze('Ok merci', context);
      expect(short.verdict, MessageVerdict.inconclusiveMessage);
      expect(
        short.limitations.map((l) => l.code),
        contains('MESSAGE_TOO_SHORT'),
      );
      final english = analyzer.analyze(
        'Your parcel is waiting for delivery, please check tomorrow.',
        context,
      );
      expect(english.verdict, MessageVerdict.inconclusiveMessage);
      expect(
        english.limitations.map((l) => l.code),
        contains('LANGUAGE_NOT_SUPPORTED'),
      );
      expect(
        verdictOf('https://bit.ly/3xYzAbC'),
        MessageVerdict.inconclusiveMessage,
        reason: 'un lien seul n’est pas un texte',
      );
    });

    test('un indice fort court l’emporte sur la longueur', () {
      expect(verdictOf('Envoie ton code'), MessageVerdict.highRiskMessage);
    });

    test('champs communs', () {
      final result = analyzer.analyze('Bonjour, à demain au bureau.', context);
      expect(result.contentType, ContentType.message);
      expect(result.processing, Processing.localOnly);
      expect(result.privacyImpact, PrivacyImpact.stayedOnDevice);
      expect(result.analyzedAt, now);
      expect(result.confidence, Confidence.low);
      expect(result.rulesVersion, analyzer.fullRulesVersion);
      expect(analyzer.fullRulesVersion, 'message-1.0.0+dico.fr-1.0.0');
      expect(analyzer.contentType, ContentType.message);
      expect(
        result.limitations.map((l) => l.code),
        containsAll(['SENDER_NOT_VERIFIED', 'TEXT_RULES_LIMITS']),
      );
    });

    test('jamais « authentique » ni « vrai »', () {
      final texts = [
        for (final text in [
          'Bonjour, à demain au bureau.',
          'Envoyez-moi le code reçu.',
          'Ok',
        ]) ...[
          ...analyzer
              .analyze(text, context)
              .limitations
              .map((l) => l.description),
          ...analyzer
              .analyze(text, context)
              .recommendedActions
              .map((a) => a.description),
        ],
      ].join(' ').toLowerCase();
      expect(texts, isNot(contains('authentique')));
      expect(texts, isNot(contains('information vraie')));
      expect(texts, isNot(contains('100 %')));
    });

    test('confiance', () {
      expect(
        analyzer.analyze('Envoyez-moi votre code PIN.', context).confidence,
        Confidence.high,
      );
      expect(
        analyzer
            .analyze('Saisissez votre code PIN sur notre page.', context)
            .confidence,
        Confidence.medium,
      );
      expect(
        analyzer
            .analyze(
              'Votre compte sera suspendu. Contactez-nous sur WhatsApp.',
              context,
            )
            .confidence,
        Confidence.medium,
      );
    });
  });

  group('gestes recommandés selon le contexte', () {
    List<String> actions(String text) => analyzer
        .analyze(text, context)
        .recommendedActions
        .map((a) => a.code)
        .toList();

    test('code, USSD, transfert, paiement, canal', () {
      expect(actions('Envoyez-moi votre code.'), contains('NEVER_SHARE_CODES'));
      expect(
        actions('Composez *144*2*70123456*5000# vite.'),
        contains('DO_NOT_DIAL'),
      );
      expect(
        actions('Je vous ai envoyé 5 000 F par erreur, renvoyez-les.'),
        contains('CHECK_BALANCE_OFFICIAL'),
      );
      expect(
        actions('Payez les frais de dossier de 5 000 F pour recevoir le prêt.'),
        contains('DO_NOT_PAY'),
      );
      expect(
        actions('Écrivez-moi sur WhatsApp pour la suite.'),
        contains('STAY_ON_OFFICIAL_CHANNELS'),
      );
      expect(
        actions('Envoyez-moi votre code.'),
        containsAll(['VERIFY_OFFICIAL_CHANNEL', 'REPORT_AND_BLOCK']),
      );
    });

    test('sans indice : vigilance, sans alarme', () {
      final codes = actions('Bonjour, à demain au bureau.');
      expect(codes, ['VERIFY_OFFICIAL_CHANNEL', 'STAY_ALERT']);
    });
  });

  group('politique de verdict', () {
    const policy = MessageVerdictPolicy();
    const french = LanguageAssessment(wordCount: 10, frenchWordCount: 6);

    MessageFinding finding(
      String code,
      Severity severity, {
      bool quoted = false,
    }) => MessageFinding(
      signal: RiskSignal(
        code: code,
        severity: severity,
        confidence: Confidence.medium,
        reason: 'test',
        source: SignalSource.messageRule,
        detectedAt: now,
      ),
      category: MessageSignalCodes.categories[code]!,
      spans: [MessageSpan(0, 1)],
      quoted: quoted,
    );

    test('paiement + gain, organisme, urgence ou menace : forts indices', () {
      for (final code in [
        MessageSignalCodes.prize,
        MessageSignalCodes.selection,
        MessageSignalCodes.impersonation,
        MessageSignalCodes.urgency,
        MessageSignalCodes.accountThreat,
      ]) {
        final (verdict, _) = policy.decide([
          finding(MessageSignalCodes.paymentRequest, Severity.medium),
          finding(code, Severity.low),
        ], french);
        expect(verdict, MessageVerdict.highRiskMessage, reason: code);
      }
    });

    test('citer un organisme ne compte pas parmi deux indices faibles', () {
      final (alone, _) = policy.decide([
        finding(MessageSignalCodes.impersonation, Severity.low),
        finding(MessageSignalCodes.urgency, Severity.low),
      ], french);
      expect(alone, MessageVerdict.noObviousSignals);
      final (two, confidence) = policy.decide([
        finding(MessageSignalCodes.callNumber, Severity.low),
        finding(MessageSignalCodes.urgency, Severity.low),
      ], french);
      expect(two, MessageVerdict.suspiciousMessage);
      expect(confidence, Confidence.low);
    });

    test('un indice cité n’entre dans aucune combinaison forte', () {
      final (verdict, _) = policy.decide([
        finding(
          MessageSignalCodes.credentialsRequest,
          Severity.low,
          quoted: true,
        ),
        finding(MessageSignalCodes.paymentRequest, Severity.low, quoted: true),
        finding(MessageSignalCodes.prize, Severity.low, quoted: true),
      ], french);
      expect(verdict, MessageVerdict.suspiciousMessage);
    });

    test('réglages de langue', () {
      const custom = MessageVerdictPolicy(
        minWords: 1,
        minWordsForLanguage: 2,
        minFrenchRatio: 0.9,
      );
      expect(custom.minWords, 1);
      const mixed = LanguageAssessment(wordCount: 4, frenchWordCount: 2);
      expect(custom.isSupportedLanguage(mixed), isFalse);
      expect(policy.isSupportedLanguage(mixed), isTrue);
      expect(custom.isLongEnough(mixed), isTrue);
    });
  });

  group('corpus annoté', () {
    final entries = parseMessageCorpus(
      File('../../data/corpus/messages.tsv').readAsStringSync(),
    );
    final report = MessageCorpusReport.evaluate(entries, analyzer);

    test('taille, natures et absence de doublons', () {
      expect(entries.length, greaterThanOrEqualTo(150));
      expect(
        entries.map((e) => e.nature).toSet(),
        containsAll(['arnaque', 'legitime', 'piege']),
      );
      final texts = entries.map((e) => e.text).toList();
      expect(texts.toSet(), hasLength(texts.length));
    });

    test('seuils bloquants', () {
      expect(report.failures, isEmpty, reason: report.toMarkdown());
      expect(report.legitimateHighRisk, isEmpty);
      expect(report.scamRecall, greaterThanOrEqualTo(0.9));
    });

    for (final outcome in report.outcomes) {
      test('ligne ${outcome.entry.line} (${outcome.entry.category})', () {
        expect(
          outcome.result.verdict,
          outcome.entry.expected,
          reason: outcome.entry.text,
        );
      });
    }

    test('rapport', () {
      final markdown = report.toMarkdown();
      expect(markdown, contains('Évaluation du corpus de messages'));
      expect(markdown, contains('| arnaque | code |'));
      expect(report.precision, greaterThan(0.9));
      expect(report.agreement, greaterThan(0.9));
      expect(report.scamHighRiskRate, greaterThan(0.5));
      expect(report.legitimateFlaggedRate, lessThan(0.25));
    });

    test('seuils non atteints et écarts signalés', () {
      final tiny = MessageCorpusReport.evaluate(
        [
          const MessageCorpusEntry(
            line: 1,
            expected: MessageVerdict.noObviousSignals,
            nature: 'legitime',
            category: 'test',
            text: 'Envoyez-moi votre code.',
            note: '',
          ),
          const MessageCorpusEntry(
            line: 2,
            expected: MessageVerdict.highRiskMessage,
            nature: 'arnaque',
            category: 'test',
            text: 'Bonjour, à demain au bureau.',
            note: '',
          ),
        ],
        analyzer,
        thresholds: const MessageCorpusThresholds(minEntries: 3),
      );
      expect(tiny.failures, hasLength(4));
      expect(tiny.toMarkdown(), contains('Écarts avec l’annotation'));
      expect(tiny.outcomes.first.entry.isLegitimate, isTrue);
      expect(tiny.outcomes.last.entry.isScam, isTrue);
    });

    test('lecture : erreurs de format', () {
      expect(() => parseMessageCorpus('a\tb'), throwsFormatException);
      expect(
        () => parseMessageCorpus('FAUX\tarnaque\tc\tt\tn'),
        throwsFormatException,
      );
      expect(
        () => parseMessageCorpus('HIGH_RISK_MESSAGE\tautre-chose\tc\tt\tn'),
        throwsFormatException,
      );
      expect(decodeCorpusText(r'a\nb'), 'a\nb');
      expect(decodeCorpusText('<vide>'), '');
      expect(decodeCorpusText('<long:50>'), hasLength(50));
    });
  });
}
