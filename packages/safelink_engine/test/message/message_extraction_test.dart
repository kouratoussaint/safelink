import 'package:safelink_engine/src/message/message_extraction.dart';
import 'package:safelink_engine/src/message/message_text.dart';
import 'package:test/test.dart';

final _extractor = MessageExtractor();

MessageExtraction extract(String text) =>
    _extractor.extract(MessagePreprocessor.prepare(text));

List<String> links(String text) =>
    extract(text).links.map((l) => l.url).toList();

void main() {
  group('liens', () {
    test('zéro, un ou plusieurs', () {
      expect(links('Bonjour, rendez-vous demain à 10 h.'), isEmpty);
      expect(links('Voir https://example.com/a'), ['https://example.com/a']);
      expect(
        links('1) https://a.example.com 2) www.orange.bf 3) lefaso.net/x'),
        ['https://a.example.com', 'www.orange.bf', 'lefaso.net/x'],
      );
    });

    test('positions dans le texte d’origine', () {
      const text = 'Écoutez : https://exemple.com/é !';
      final link = extract(text).links.single;
      expect(link.span.of(text), 'https://exemple.com/é');
      expect(link.written, 'https://exemple.com/é');
      expect(link.hasScheme, isTrue);
      expect(link.isDefanged, isFalse);
      expect(link.toString(), startsWith('ExtractedLink('));
      expect(link, extract(text).links.single);
      expect(link.hashCode, extract(text).links.single.hashCode);
    });

    test('formes déguisées rétablies et signalées', () {
      for (final (written, url) in [
        ('hxxp://evil.example/x', 'http://evil.example/x'),
        ('hXXps://evil.example', 'https://evil.example'),
        ('hxxp[s]://evil.example', 'https://evil.example'),
        ('h**p://evil.example', 'http://evil.example'),
        ('h[tt]ps://evil.example', 'https://evil.example'),
        ('https[://]evil.example', 'https://evil.example'),
        ('https[:]//evil.example', 'https://evil.example'),
        ('evil[.]com/login', 'evil.com/login'),
        ('evil(.)com', 'evil.com'),
        ('evil{.}com', 'evil.com'),
        ('evil[dot]com', 'evil.com'),
        ('www[.]evil[.]com', 'www.evil.com'),
      ]) {
        final link = extract('Attention : $written merci').links.single;
        expect(link.url, url, reason: written);
        expect(link.isDefanged, isTrue, reason: written);
        expect(link.written, written, reason: written);
      }
    });

    test('ponctuation finale exclue, parenthèses du lien gardées', () {
      expect(links('Lien : https://example.com/a.'), ['https://example.com/a']);
      expect(links('(voir https://example.com/a)'), ['https://example.com/a']);
      expect(links('https://fr.wikipedia.org/wiki/Ouaga_(ville), fin'), [
        'https://fr.wikipedia.org/wiki/Ouaga_(ville)',
      ]);
      expect(links('« www.orange.bf »'), ['www.orange.bf']);
      expect(links('Allez sur lefaso.net!'), ['lefaso.net']);
    });

    test('domaines nus : seulement avec une extension réelle', () {
      expect(links('Site : orange-bonus.top'), ['orange-bonus.top']);
      expect(links('Site : bücher.de'), ['bücher.de']);
      expect(links('M.Ouédraogo a payé 5.000 F, fichier.txt, v1.2'), isEmpty);
      expect(links('Prix 3.5 kg'), isEmpty);
    });

    test('adresses e-mail exclues', () {
      expect(links('Écrivez à jean.dupont@example.com'), isEmpty);
      expect(links('support@orange.bf ou www.orange.bf'), ['www.orange.bf']);
    });

    test('lien avec protocole mais hôte invalide : conservé pour analyse', () {
      expect(links('http://256.256.256.256/x'), ['http://256.256.256.256/x']);
    });
  });

  group('numéros de téléphone', () {
    test('formats local et international', () {
      final phones = extract(
        'Appelez le +226 70 12 34 56, le 0022676543210 ou le 70.12.34.56 '
        'ou 70123456.',
      ).phoneNumbers;
      expect(phones.map((p) => p.digits), [
        '+22670123456',
        '+22676543210',
        '70123456',
        '70123456',
      ]);
      expect(phones.first.isInternational, isTrue);
      expect(phones.last.isInternational, isFalse);
      expect(phones.first.toString(), startsWith('ExtractedPhoneNumber('));
      expect(phones[2], isNot(phones[3]));
      expect(phones[2].hashCode, isNot(phones[3].hashCode));
    });

    test('ni montant, ni date, ni code USSD', () {
      final extraction = extract(
        'Payez 10 000 000 FCFA le 27/11/2026 avec *144*2*70123456#.',
      );
      expect(extraction.phoneNumbers, isEmpty);
      expect(extraction.amounts.single.value, 10000000);
      expect(extraction.ussdCodes.single.code, '*144*2*70123456#');
    });
  });

  group('codes USSD', () {
    test('codes de service et codes de transfert', () {
      final codes = extract(
        'Composez *144# puis #111# ou *144*2*1*70123456*5000#.',
      ).ussdCodes;
      expect(codes.map((c) => c.code), [
        '*144#',
        '#111#',
        '*144*2*1*70123456*5000#',
      ]);
      expect(codes[0].carriesTransferData, isFalse);
      expect(codes[0].groups, ['144']);
      expect(codes[2].carriesTransferData, isTrue);
      expect(codes[2].groups, ['144', '2', '1', '70123456', '5000']);
      expect(codes[0].toString(), 'ExtractedUssdCode(*144#)');
      expect(codes[0], isNot(codes[1]));
      expect(codes[0].hashCode, isNot(codes[1].hashCode));
    });

    test('pas d’étoile isolée', () {
      expect(extract('Note : 5* sur 5, code 1234#').ussdCodes, isEmpty);
    });
  });

  group('montants', () {
    test('formes usuelles du franc CFA', () {
      final amounts = extract(
        'Envoyez 5.000F, 25 000 FCFA, 1000 F CFA, 10\u202F000 francs CFA, '
        '300 frs, FCFA 7500, 2500 XOF, 12 000,50 cfa et 3 fois rien.',
      ).amounts;
      expect(amounts.map((a) => a.value), [
        5000,
        25000,
        1000,
        10000,
        300,
        7500,
        2500,
        12000,
      ]);
      expect(amounts.first.toString(), 'ExtractedAmount(5000)');
      expect(amounts[0], isNot(amounts[1]));
      expect(amounts[0].hashCode, isNot(amounts[1].hashCode));
    });

    test('position d’origine avec espace insécable', () {
      const text = 'Total : 10\u00A0000 FCFA';
      final amount = extract(text).amounts.single;
      expect(amount.span.of(text), '10\u00A0000 FCFA');
    });

    test('nombres trop longs ignorés', () {
      expect(extract('${'9' * 20} FCFA').amounts, isEmpty);
    });
  });

  test('texte long, émojis et lignes multiples', () {
    final buffer = StringBuffer();
    while (buffer.length < 10000) {
      buffer.write('Bonjour 😀, voir www.exemple.com et payez 5 000 F.\n');
    }
    final text = buffer.toString().substring(0, 10000);
    final stopwatch = Stopwatch()..start();
    final extraction = extract(text);
    stopwatch.stop();
    expect(extraction.links, isNotEmpty);
    expect(extraction.amounts, isNotEmpty);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
