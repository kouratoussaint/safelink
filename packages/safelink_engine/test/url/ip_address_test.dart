import 'package:safelink_engine/src/url/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('IpAddress.endsInNumber', () {
    test('cas du standard URL', () {
      expect(IpAddress.endsInNumber('1.2.3.4'), isTrue);
      expect(IpAddress.endsInNumber('example.0x10'), isTrue);
      expect(IpAddress.endsInNumber('example.1.'), isTrue);
      expect(IpAddress.endsInNumber('example.com'), isFalse);
      expect(IpAddress.endsInNumber('example.0xg'), isFalse);
      expect(IpAddress.endsInNumber(''), isFalse);
    });
  });

  group('IpAddress.parseIpv4', () {
    test('formes décimale, octale, hexadécimale et abrégées', () {
      const expected = 0xC0A80101;
      for (final text in [
        '192.168.1.1',
        '3232235777',
        '0xC0.0xA8.0x1.0x1',
        '0300.0250.01.01',
        '192.168.257',
        '192.11010305',
        '192.168.1.1.',
      ]) {
        expect(IpAddress.parseIpv4(text), expected, reason: text);
      }
      expect(IpAddress.parseIpv4('0'), 0);
      expect(IpAddress.parseIpv4('0x'), 0);
      expect(IpAddress.parseIpv4('4294967295'), 0xFFFFFFFF);
    });

    test('formes invalides', () {
      for (final text in [
        '4294967296',
        '1.2.3.256',
        '256.1.1.1',
        '1.2.3.4.5',
        '1..2.3',
        '09',
        '1x2',
        '1.2.3.${'9' * 40}',
      ]) {
        expect(IpAddress.parseIpv4(text), isNull, reason: text);
      }
    });

    test('affichage', () {
      expect(IpAddress.formatIpv4(0xC0A80101), '192.168.1.1');
      expect(IpAddress.formatIpv4(0), '0.0.0.0');
    });
  });

  group('IpAddress.isNonPublicIpv4', () {
    int ip(String text) => IpAddress.parseIpv4(text)!;

    test('plages privées, locales et réservées', () {
      for (final text in [
        '0.1.2.3',
        '10.0.0.1',
        '127.0.0.1',
        '100.64.0.1',
        '100.127.255.255',
        '169.254.1.1',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.0.1',
        '224.0.0.1',
        '255.255.255.255',
      ]) {
        expect(IpAddress.isNonPublicIpv4(ip(text)), isTrue, reason: text);
      }
    });

    test('adresses publiques', () {
      for (final text in [
        '8.8.8.8',
        '100.63.255.255',
        '100.128.0.1',
        '169.253.1.1',
        '172.15.0.1',
        '172.32.0.1',
        '192.169.0.1',
        '223.255.255.255',
      ]) {
        expect(IpAddress.isNonPublicIpv4(ip(text)), isFalse, reason: text);
      }
    });
  });

  group('IPv6', () {
    test('lecture et forme compressée', () {
      String format(String text) =>
          IpAddress.formatIpv6(IpAddress.parseIpv6(text)!);
      expect(format('0:0:0:0:0:0:0:1'), '::1');
      expect(
        format('2001:0db8:0000:0000:0001:0000:0000:0001'),
        '2001:db8::1:0:0:1',
      );
      // À longueur égale, la première suite de zéros est compressée.
      expect(format('fe80:0:0:0:1:0:0:0'), 'fe80::1:0:0:0');
      expect(format('1:0:0:2:0:0:0:3'), '1:0:0:2::3');
      expect(format('1:2:3:4:5:6:7:8'), '1:2:3:4:5:6:7:8');
      expect(IpAddress.parseIpv6('1::2::3'), isNull);
      expect(IpAddress.parseIpv6('fe80::1%25eth0'), isNull);
    });
  });
}
