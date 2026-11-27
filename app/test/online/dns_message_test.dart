import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/online/dns_message.dart';

import '../helpers/fake_online.dart';

void main() {
  group('requête', () {
    test('question A pour le nom, avec EDNS', () {
      final query = DnsMessage.query('www.exemple.bf');
      expect(query.sublist(0, 12), [0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
      expect(FakeDohTransport.nameOf(query), 'www.exemple.bf');
      // Fin de la question : type A, classe IN, puis l'enregistrement OPT.
      final end = query.length - 11;
      expect(query.sublist(end - 4, end), [0, 1, 0, 1]);
      expect(query.sublist(end), [0, 0, 41, 4, 208, 0, 0, 0, 0, 0, 0]);
    });

    test('point final ignoré ; nom non ASCII ou trop long refusé', () {
      expect(
        FakeDohTransport.nameOf(DnsMessage.query('exemple.bf.')),
        'exemple.bf',
      );
      expect(() => DnsMessage.query('café.bf'), throwsArgumentError);
      expect(() => DnsMessage.query('${'a' * 64}.bf'), throwsArgumentError);
    });
  });

  group('réponse', () {
    test('adresses et nom existant', () {
      final response = DnsMessage.parse(
        dnsAnswer(addresses: const ['93.184.215.14', '1.2.3.4']),
      );
      expect(response.exists, isTrue);
      expect(response.isNameError, isFalse);
      expect(response.addresses, ['93.184.215.14', '1.2.3.4']);
      expect(response.isBlocked, isFalse);
      expect(response.extendedErrors, isEmpty);
    });

    test('nom inexistant (NXDOMAIN avec SOA)', () {
      final response = DnsMessage.parse(
        dnsAnswer(rcode: 3, addresses: const [], authorities: 1),
      );
      expect(response.isNameError, isTrue);
      expect(response.authorityCount, 1);
      expect(response.isBlocked, isFalse);
    });

    test('blocage Quad9 : NXDOMAIN et erreur étendue 17', () {
      final response = DnsMessage.parse(
        dnsAnswer(rcode: 3, addresses: const [], extendedError: 17),
      );
      expect(response.extendedErrors, {17});
      expect(response.isBlocked, isTrue);
    });

    test('blocage Cloudflare : adresse 0.0.0.0', () {
      final response = DnsMessage.parse(
        dnsAnswer(addresses: const ['0.0.0.0']),
      );
      expect(response.isBlocked, isTrue);
    });

    test('erreur étendue sans rapport avec un blocage', () {
      final response = DnsMessage.parse(dnsAnswer(extendedError: 18));
      expect(response.extendedErrors, {18});
      expect(response.isBlocked, isFalse);
    });

    test('vraie réponse de Quad9 pour un domaine bloqué', () {
      // isitblocked.org via dns.quad9.net, capturée le 27/11/2026.
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x81, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, //
        0x00, 0x01, 0x0b, ...'isitblocked'.codeUnits, 0x03,
        ...'org'.codeUnits, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x29,
        0x04, 0xd0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x0f, 0x00,
        0x02, 0x00, 0x11,
      ]);
      final response = DnsMessage.parse(bytes);
      expect(response.isNameError, isTrue);
      expect(response.isBlocked, isTrue);
    });

    test('réponse tronquée, question au lieu de réponse : refus', () {
      final good = dnsAnswer();
      expect(
        () => DnsMessage.parse(good.sublist(0, good.length - 3)),
        throwsFormatException,
      );
      expect(
        () => DnsMessage.parse(DnsMessage.query('exemple.bf')),
        throwsFormatException,
      );
      expect(() => DnsMessage.parse(const [0, 0]), throwsFormatException);
    });

    test('étiquette de type inconnu : refus', () {
      final bad = dnsAnswer()..[12] = 0x80;
      expect(() => DnsMessage.parse(bad), throwsFormatException);
    });
  });
}
