import 'package:safelink_engine/src/message/message_text.dart';
import 'package:test/test.dart';

void main() {
  group('MessageSpan', () {
    test('bornes, contenance et chevauchement', () {
      final span = MessageSpan(2, 6);
      expect(span.length, 4);
      expect(span.of('abcdefgh'), 'cdef');
      expect(span.contains(MessageSpan(3, 5)), isTrue);
      expect(span.contains(MessageSpan(1, 5)), isFalse);
      expect(span.overlaps(MessageSpan(5, 9)), isTrue);
      expect(span.overlaps(MessageSpan(6, 9)), isFalse);
      expect(span, MessageSpan(2, 6));
      expect(span.hashCode, MessageSpan(2, 6).hashCode);
      expect(span.toString(), 'MessageSpan(2, 6)');
      expect(() => MessageSpan(-1, 2), throwsArgumentError);
      expect(() => MessageSpan(3, 2), throwsArgumentError);
    });
  });

  group('FoldedText', () {
    test('minuscules, accents, apostrophes, guillemets, tirets, espaces', () {
      final folded = FoldedText(
        'Écrivez-moi l’après\u2011midi « VITE » : 5\u202F000 Œuvre',
      );
      expect(folded.text, 'ecrivez-moi l\'apres-midi " vite " : 5 000 oeuvre');
    });

    test('caractères invisibles retirés', () {
      expect(FoldedText('co\u200Bde P\u00ADIN\u202E').text, 'code pin');
    });

    test('ligatures et pleine chasse', () {
      expect(
        FoldedText('Æsop straße \uFF23\uFF2F\uFF24\uFF25').text,
        'aesop strasse code',
      );
    });

    test('positions d’origine conservées, émojis compris', () {
      const original = 'Gagné 😀 Évitez';
      final folded = FoldedText(original);
      final start = folded.text.indexOf('evitez');
      final span = folded.toOriginal(start, start + 'evitez'.length);
      expect(span.of(original), 'Évitez');
      final emoji = folded.text.indexOf('😀');
      expect(folded.toOriginal(emoji, emoji + 2).of(original), '😀');
      final gagne = folded.toOriginal(0, 5);
      expect(gagne.of(original), 'Gagné');
    });

    test('caractère replié en plusieurs : portion entière', () {
      const original = 'cœur';
      final folded = FoldedText(original);
      expect(folded.text, 'coeur');
      expect(folded.toOriginal(1, 2).of(original), 'œ');
      expect(folded.toOriginal(2, 3).of(original), 'œ');
    });

    test('portions vides et conversion inverse', () {
      final folded = FoldedText('abc');
      expect(folded.toOriginal(1, 1), MessageSpan(1, 1));
      expect(folded.toOriginal(3, 3), MessageSpan(3, 3));
      expect(folded.toFolded(0), 0);
      expect(folded.toFolded(2), 2);
      expect(folded.toFolded(10), 3);
      final accented = FoldedText('a\u0301b');
      expect(accented.text, 'ab');
      expect(accented.toFolded(2), 1);
    });
  });

  group('PreparedMessage', () {
    test('phrases', () {
      final message = MessagePreprocessor.prepare(
        'Bonjour. Votre colis est arrivé !\nPayez vite? 3.5 kg… fin',
      );
      final sentences = message.sentences.map((s) => s.of(message.text));
      expect(sentences, [
        'bonjour.',
        ' votre colis est arrive !',
        '\n',
        'payez vite?',
        ' 3.5 kg...',
        ' fin',
      ]);
      expect(message.original, startsWith('Bonjour.'));
      expect(message.sentenceAt(2).of(message.text), 'bonjour.');
    });

    test('citations entre guillemets et lignes « > »', () {
      final message = MessagePreprocessor.prepare(
        'Ils écrivent « envoyez votre code » puis "payez".\n'
        '> Ne cliquez pas\nFin "ouvert',
      );
      final quoted = message.quotations.map((q) => q.of(message.text)).toList();
      expect(quoted, ['" envoyez votre code "', '"payez"', '> ne cliquez pas']);
      final code = message.text.indexOf('code');
      expect(message.isQuoted(MessageSpan(code, code + 4)), isTrue);
      final fin = message.text.indexOf('fin');
      expect(message.isQuoted(MessageSpan(fin, fin + 3)), isFalse);
    });

    test('négations', () {
      bool negated(String text, String word) {
        final message = MessagePreprocessor.prepare(text);
        final start = message.text.indexOf(word);
        return message.isNegated(MessageSpan(start, start + word.length));
      }

      expect(
        negated('Ne communiquez jamais votre code', 'communiquez'),
        isTrue,
      );
      expect(negated('Ne le communiquez à personne', 'communiquez'), isTrue);
      expect(negated("N'envoyez pas d'argent", 'envoyez'), isTrue);
      expect(negated('Aucun agent ne demande votre PIN', 'demande'), isTrue);
      expect(negated('Envoyez votre code', 'envoyez'), isFalse);
      expect(
        negated('Ne tardez pas, envoyez votre code', 'envoyez'),
        isFalse,
        reason: 'la négation est dans une autre proposition',
      );
      expect(negated("N'oubliez pas d'envoyer le code", 'envoyer'), isFalse);
      expect(negated("N'hésitez pas à envoyer le code", 'envoyer'), isFalse);
      expect(
        negated('Si vous ne payez pas, le compte sera bloqué', 'payez'),
        isFalse,
      );
    });

    test('début de proposition', () {
      final message = MessagePreprocessor.prepare('Bonjour, payez (vite) ici');
      expect(message.clauseStart(message.text.indexOf('payez')), 8);
      expect(message.clauseStart(message.text.indexOf('ici')), 21);
      expect(message.clauseStart(0), 0);
    });

    test('langue', () {
      final french = MessagePreprocessor.prepare(
        'Bonjour, votre colis est en attente de livraison.',
      ).language;
      expect(french.wordCount, 8);
      expect(french.frenchRatio, greaterThan(0.3));
      final english = MessagePreprocessor.prepare(
        'Your parcel is waiting for delivery, click the link below',
      ).language;
      expect(english.frenchRatio, lessThan(0.12));
      final sms = MessagePreprocessor.prepare('slt cv stp rappelle moi')
          .language;
      expect(sms.frenchRatio, greaterThan(0.5));
      expect(MessagePreprocessor.prepare('😀 123').language.frenchRatio, 0);
      const assessment = LanguageAssessment(wordCount: 4, frenchWordCount: 1);
      expect(assessment.frenchRatio, 0.25);
    });
  });
}
