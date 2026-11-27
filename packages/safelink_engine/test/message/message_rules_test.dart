import 'dart:io';

import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

final _extractor = MessageExtractor();
final _rules = MessageRules();

List<MessageFinding> findings(String text) {
  final message = MessagePreprocessor.prepare(text);
  return _rules.evaluate(
    message,
    _extractor.extract(message),
    DateTime.utc(2026, 11, 27),
  );
}

Map<String, Severity> codes(String text) => {
  for (final f in findings(text)) f.signal.code: f.signal.severity,
};

void main() {
  group('aucun mot isolé ne vaut preuve', () {
    test('mots courants sans construction', () {
      for (final text in [
        'Code',
        'C’est urgent ?',
        'Le transfert est arrivé, merci.',
        'J’ai reçu le code, merci.',
        'Payez à la livraison.',
        'Votre code de confirmation est 482913.',
        'Tu as gagné le match hier ?',
        'Le bonus de fin d’année a été versé.',
        'Rappelle-moi quand tu peux.',
      ]) {
        final found = codes(text).values.where((s) => s.rank >= 2);
        expect(found, isEmpty, reason: text);
      }
    });

    test('« ne communiquez jamais votre code » est un conseil', () {
      for (final text in [
        'Ne communiquez jamais votre code.',
        'Ne le communiquez à personne.',
        'Votre code est 482913. Ne le partagez avec personne.',
        'Orange ne vous demandera jamais votre code secret.',
        'Aucun agent ne vous demandera votre PIN.',
        'Attention : si quelqu’un vous demande votre code, raccrochez.',
        'Méfiez-vous des escrocs qui demandent votre mot de passe.',
        'Ne saisissez jamais votre code secret sur un site.',
      ]) {
        expect(
          codes(text).keys,
          isNot(contains(MessageSignalCodes.credentialsRequest)),
          reason: text,
        );
        expect(
          codes(text).keys,
          isNot(contains(MessageSignalCodes.secretEntry)),
          reason: text,
        );
      }
    });
  });

  group('demande d’identifiants ou de code', () {
    test('verbe de transmission et secret', () {
      for (final text in [
        'Envoyez-moi le code que vous venez de recevoir.',
        'Donnez-lui votre code PIN pour finaliser.',
        'Communiquez-nous votre mot de passe.',
        'Merci de transmettre le code de validation reçu par SMS.',
        'Le code que tu as reçu, envoie-le moi vite.',
        'Nous vous demandons votre code secret pour la mise à jour.',
        'N’oubliez pas d’envoyer votre code OTP.',
      ]) {
        expect(
          codes(text)[MessageSignalCodes.credentialsRequest],
          Severity.high,
          reason: text,
        );
      }
    });

    test('saisie d’un secret qu’aucun service ne fait saisir', () {
      expect(
        codes(
          'Saisissez votre code PIN sur ce lien.',
        )[MessageSignalCodes.secretEntry],
        Severity.high,
      );
      expect(
        codes('Saisissez le code 482913 sur le site pour payer.').keys,
        isNot(contains(MessageSignalCodes.secretEntry)),
        reason: 'un code à usage unique saisi sur le site est normal',
      );
    });
  });

  group('paiement ou frais anticipés', () {
    test('frais, but ou destinataire', () {
      for (final text in [
        'Payez les frais de dossier de 5 000 F pour recevoir votre prêt.',
        'Envoyez 10 000 FCFA au 70 12 34 56 pour débloquer le colis.',
        'Frais de déblocage : 15 000 F.',
        'Pour recevoir votre gain, faites un dépôt de 2 500 F.',
        'Si vous ne payez pas 2000 F, votre ligne sera coupée.',
        'Frais d’inscription 10 000 F à envoyer par Orange Money.',
      ]) {
        expect(
          codes(text)[MessageSignalCodes.paymentRequest],
          Severity.medium,
          reason: text,
        );
      }
    });

    test('facture, reçu ou conseil : pas de demande', () {
      for (final text in [
        'Vous avez reçu 25 000 F de 70 12 34 56. Nouveau solde : 40 000 F.',
        'Retrait de 10 000 F effectué. Frais : 200 F.',
        'Votre facture de 12 500 F est disponible. Payez avant le 30/11.',
        'N’envoyez jamais d’argent pour recevoir un gain.',
        'Envoyez-moi le code pour valider.',
        'Livraison sans frais pour recevoir vos achats.',
      ]) {
        expect(
          codes(text).keys,
          isNot(contains(MessageSignalCodes.paymentRequest)),
          reason: text,
        );
      }
    });
  });

  group('autres catégories', () {
    test('gain ou cadeau', () {
      expect(
        codes(
          'Félicitations, vous avez gagné un téléphone !',
        )[MessageSignalCodes.prize],
        Severity.medium,
      );
      expect(
        codes('Vous êtes l’heureux gagnant du tirage au sort.').keys,
        contains(MessageSignalCodes.prize),
      );
      expect(
        codes('Vous n’avez pas gagné cette fois.').keys,
        isNot(contains(MessageSignalCodes.prize)),
      );
    });

    test('menace de blocage', () {
      expect(
        codes(
          'Votre compte sera suspendu dans 24 h.',
        )[MessageSignalCodes.accountThreat],
        Severity.medium,
      );
      expect(
        codes('Votre carte a été bloquée suite à 3 erreurs.').keys,
        contains(MessageSignalCodes.accountThreat),
      );
      expect(
        codes('Votre compte ne sera pas suspendu.').keys,
        isNot(contains(MessageSignalCodes.accountThreat)),
      );
    });

    test('usurpation déclarée : indice faible', () {
      expect(
        codes(
          'Le service client Orange vous informe.',
        )[MessageSignalCodes.impersonation],
        Severity.low,
      );
      expect(
        codes('Votre banque vous contacte.')[MessageSignalCodes.impersonation],
        Severity.low,
      );
      expect(codes('Bonjour, à demain.'), isEmpty);
    });

    test('sortie du canal officiel', () {
      expect(
        codes(
          'Contactez-nous sur WhatsApp pour la suite.',
        )[MessageSignalCodes.offChannel],
        Severity.medium,
      );
      expect(
        codes('Appelez vite le 70 12 34 56.')[MessageSignalCodes.callNumber],
        Severity.low,
      );
      expect(
        codes('Ne nous écrivez pas sur WhatsApp.').keys,
        isNot(contains(MessageSignalCodes.offChannel)),
      );
    });

    test('urgence : indice faible', () {
      for (final text in [
        'C’est urgent.',
        'Dernier délai : ce soir.',
        'Répondez sous 24 h.',
        'Offre valable aujourd’hui seulement.',
        'Agissez immédiatement.',
      ]) {
        expect(
          codes(text)[MessageSignalCodes.urgency],
          Severity.low,
          reason: text,
        );
      }
    });

    test('lien qui ne correspond pas à la marque citée', () {
      expect(
        codes(
          'Orange : réactivez votre compte sur orange-verif.top',
        )[MessageSignalCodes.linkBrandMismatch],
        Severity.medium,
      );
      expect(
        codes('Orange : nos offres sur www.orange.bf').keys,
        isNot(contains(MessageSignalCodes.linkBrandMismatch)),
      );
      expect(
        codes('Voir lefaso.net').keys,
        isNot(contains(MessageSignalCodes.linkBrandMismatch)),
      );
      expect(
        codes('Orange : http://256.256.256.256/x').keys,
        isNot(contains(MessageSignalCodes.linkBrandMismatch)),
      );
    });

    test('lien déguisé : information', () {
      expect(
        codes(
          'Attention à hxxp://faux[.]example',
        )[MessageSignalCodes.defangedLink],
        Severity.info,
      );
    });
  });

  group('variantes locales', () {
    test('transfert « par erreur »', () {
      expect(
        codes(
          'Je vous ai envoyé 25 000 F par erreur, svp renvoyez-les moi.',
        )[MessageSignalCodes.mistakenTransfer],
        Severity.high,
      );
      expect(
        codes(
          'Désolé, transfert par erreur.',
        )[MessageSignalCodes.mistakenTransfer],
        Severity.medium,
      );
      expect(
        codes(
          'Je me suis trompé de numéro, remboursez-moi.',
        )[MessageSignalCodes.mistakenTransfer],
        Severity.high,
      );
    });

    test('code USSD de transfert', () {
      expect(
        codes(
          'Composez *144*2*1*70123456*5000# pour activer.',
        )[MessageSignalCodes.ussdTransfer],
        Severity.high,
      );
      expect(
        codes(
          'Code : *144*2*1*70123456*5000#',
        )[MessageSignalCodes.ussdTransfer],
        Severity.medium,
      );
      expect(
        codes('Composez *144# pour consulter votre solde.').keys,
        isNot(contains(MessageSignalCodes.ussdTransfer)),
      );
    });
  });

  group('citations, extraits et positions', () {
    test('un passage cité compte moins', () {
      final found = findings(
        'Ils écrivent « Envoyez votre code PIN pour débloquer ».',
      );
      final request = found.firstWhere(
        (f) => f.signal.code == MessageSignalCodes.credentialsRequest,
      );
      expect(request.quoted, isTrue);
      expect(request.signal.severity, Severity.low);
      expect(request.signal.confidence, Confidence.low);
      expect(request.signal.reason, contains('cité'));
    });

    test('une occurrence hors citation l’emporte', () {
      final request =
          findings(
            '« Envoyez votre code » disent-ils. Envoyez votre code maintenant.',
          ).firstWhere(
            (f) => f.signal.code == MessageSignalCodes.credentialsRequest,
          );
      expect(request.quoted, isFalse);
      expect(request.signal.severity, Severity.high);
      expect(request.spans, hasLength(2));
    });

    test('passages en positions d’origine, extraits expurgés', () {
      const text =
          'Écrivez à jean@example.com. Envoyez-moi le code 482913 '
          'au 70 12 34 56 pour débloquer 5 000 FCFA.';
      final found = findings(text);
      final request = found.firstWhere(
        (f) => f.signal.code == MessageSignalCodes.credentialsRequest,
      );
      expect(request.spans.first.of(text), 'Envoyez-moi le code');
      for (final finding in found) {
        final evidence = finding.signal.evidence ?? '';
        expect(evidence, isNot(contains('482913')));
        expect(evidence, isNot(contains('70 12 34')));
        expect(evidence, isNot(contains('jean@')));
        expect(finding.signal.source, SignalSource.messageRule);
        expect(finding.toString(), startsWith('MessageFinding('));
      }
      final payment = found.firstWhere(
        (f) => f.signal.code == MessageSignalCodes.paymentRequest,
      );
      expect(payment.signal.evidence, contains('5 000 FCFA'));
      expect(payment.signal.evidence, contains('•• •• •• 56'));
    });

    test('extraits limités à 120 caractères', () {
      final text =
          'Payez les frais de dossier de 5 000 F pour recevoir '
          '${'votre très beau cadeau ' * 10}.';
      for (final finding in findings(text)) {
        expect(
          finding.signal.evidence!.length,
          lessThanOrEqualTo(RiskSignal.maxEvidenceLength),
        );
      }
    });

    test('un extrait ne coupe ni un mot ni une somme', () {
      String evidenceOf(String text, String code) =>
          findings(text)
              .firstWhere((f) => f.signal.code == code)
              .signal
              .evidence!;

      expect(
        evidenceOf(
          'Félicitations, vous avez gagné 500 000 FCFA ce matin.',
          MessageSignalCodes.prize,
        ),
        'vous avez gagné 500 000 FCFA',
      );
      expect(
        evidenceOf('Tu as gagné 2 500 F chez nous.', MessageSignalCodes.prize),
        'Tu as gagné 2 500 F',
      );
      expect(
        evidenceOf(
          'Vous avez remporté un smartphone neuf.',
          MessageSignalCodes.prize,
        ),
        'Vous avez remporté un smartphone',
      );
    });

    test('tri : du plus grave au moins grave', () {
      final found = findings(
        'Urgent ! Vous avez gagné. Envoyez votre code au service client.',
      );
      final ranks = found.map((f) => f.signal.severity.rank).toList();
      expect(ranks, [...ranks]..sort((a, b) => b.compareTo(a)));
      expect(found.first.signal.code, MessageSignalCodes.credentialsRequest);
    });
  });

  group('dictionnaire et codes', () {
    test('version, catégories et documentation', () {
      expect(MessageDictionary.french.version, matches(RegExp(r'^fr-\d+\.')));
      expect(_rules.dictionary, same(MessageDictionary.french));
      expect(
        MessageSignalCodes.all.toSet(),
        hasLength(MessageSignalCodes.all.length),
      );
      expect(
        MessageSignalCodes.categories.keys.toSet(),
        MessageSignalCodes.all.toSet(),
      );
      expect(
        MessageSignalCodes.categories.values.toSet(),
        MessageSignalCategory.values.toSet(),
      );
      final doc = File('../../docs/MESSAGE_RULES.md').readAsStringSync();
      final documented = RegExp(
        r'^\| `(MSG_[A-Z_]+)`',
        multiLine: true,
      ).allMatches(doc).map((m) => m[1]).toList();
      expect(documented, MessageSignalCodes.all);
    });

    test('dictionnaire injectable', () {
      final base = MessageDictionary.french;
      final custom = MessageDictionary(
        version: 'test-1',
        transmissionVerbs: base.transmissionVerbs,
        entryVerbs: base.entryVerbs,
        secrets: base.secrets,
        strongSecrets: base.strongSecrets,
        paymentVerbs: base.paymentVerbs,
        paymentPurposes: base.paymentPurposes,
        scamFees: base.scamFees,
        ordinaryFees: base.ordinaryFees,
        prizes: [PhrasePattern('test', 'gros lot')],
        selections: const [],
        accountThreats: base.accountThreats,
        impersonations: const [],
        messagingApps: base.messagingApps,
        contactVerbs: base.contactVerbs,
        urgencies: const [],
        mistakenTransfers: base.mistakenTransfers,
        returnRequests: base.returnRequests,
        dialVerbs: base.dialVerbs,
        linkActionVerbs: base.linkActionVerbs,
      );
      final rules = MessageRules(dictionary: custom);
      final message = MessagePreprocessor.prepare('Le gros lot est à vous.');
      final found = rules.evaluate(
        message,
        _extractor.extract(message),
        DateTime.utc(2026),
      );
      expect(found.single.signal.code, MessageSignalCodes.prize);
      expect(custom.prizes.single.id, 'test');
    });
  });
}
