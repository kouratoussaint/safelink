import 'dart:convert';
import 'dart:io';

import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/brands_data.g.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/public_suffix_list.dart';
import 'package:safelink_engine/src/url/url_parser.dart';
import 'package:test/test.dart';

final _parser = UrlParser();
final _matcher = BrandMatcher();

List<BrandMatch> matches(String url) =>
    _matcher.matchUrl(_parser.parse(url) as ParsedUrl);

BrandMatch? strongest(String url) {
  final found = matches(url);
  return found.isEmpty ? null : found.first;
}

void main() {
  group('liste de référence', () {
    final psl = PublicSuffixList.embedded;

    test('chaque domaine officiel est sourcé et daté', () {
      expect(embeddedBrands, hasLength(greaterThanOrEqualTo(40)));
      final today = DateTime.now().toUtc();
      for (final brand in embeddedBrands) {
        expect(brand.sources, isNotEmpty, reason: brand.id);
        final sourced = {for (final s in brand.sources) ...s.domains};
        expect(sourced, brand.domains.toSet(), reason: brand.id);
        for (final source in brand.sources) {
          expect(source.url, startsWith('https://'), reason: brand.id);
          expect(source.kind.description, isNotEmpty);
        }
        final verified = DateTime.parse(brand.verifiedOn);
        expect(verified.isAfter(today), isFalse, reason: brand.id);
        expect(brand.category.label, isNotEmpty);
      }
    });

    test('chaque domaine officiel est un domaine enregistrable', () {
      for (final brand in embeddedBrands) {
        for (final domain in brand.domains) {
          expect(
            psl.lookup(domain)?.registrableDomain,
            domain,
            reason: '${brand.id} : $domain',
          );
        }
      }
    });

    test('identifiants et domaines uniques', () {
      final ids = embeddedBrands.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final domains = [for (final b in embeddedBrands) ...b.domains];
      expect(domains.toSet(), hasLength(domains.length));
    });

    test('le code Dart correspond au fichier JSON', () {
      final json = jsonDecode(
        File('data/brands.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final entries = (json['brands'] as List).cast<Map<String, dynamic>>();
      expect(entries.map((e) => e['id']), embeddedBrands.map((b) => b.id));
      for (final (i, entry) in entries.indexed) {
        expect(entry['domains'], embeddedBrands[i].domains);
        expect(entry['verified_on'], embeddedBrands[i].verifiedOn);
      }
    });

    test('registre', () {
      final registry = BrandRegistry.embedded;
      final paypal = registry.byId('paypal')!;
      expect(registry.ownerOf('paypal.com'), paypal);
      expect(registry.ownerOf('paypal.bf'), isNull);
      expect(registry.byId('inexistant'), isNull);
      expect(registry.labelsOf(registry.byId('coris_bank')!), {
        'coris',
        'coris-bank',
      });
      expect(registry.labelsOf(registry.byId('google')!), {'google'});
      expect(paypal, isNot(registry.byId('visa')));
      expect(paypal.hashCode, 'paypal'.hashCode);
      expect(paypal.toString(), 'Brand(paypal)');
    });
  });

  group('rapprochements', () {
    test('domaine officiel, sous-domaines compris', () {
      final match = strongest('https://www.paypal.com/signin')!;
      expect(match.kind, BrandMatchKind.official);
      expect(match.brand.id, 'paypal');
      expect(matches('https://www.paypal.com/signin'), hasLength(1));
      expect(
        strongest('https://mail.google.com')!.kind,
        BrandMatchKind.official,
      );
      expect(strongest('https://burkina.coris.bank')!.brand.id, 'coris_bank');
      expect(strongest('https://www.orange.bf')!.brand.id, 'orange');
    });

    test('caractères trompeurs', () {
      for (final (url, brand) in [
        ('https://pаypаl.com', 'paypal'),
        ('https://paypa1.com', 'paypal'),
        ('https://faceb00k.com/login', 'facebook'),
        ('https://rnicrosoft.com', 'microsoft'),
        ('https://х.com', 'x'),
        ('https://orаnge.bf', 'orange'),
        ('https://pàypal.com', 'paypal'),
      ]) {
        final match = strongest(url);
        expect(match?.kind, BrandMatchKind.lookalike, reason: url);
        expect(match?.brand.id, brand, reason: url);
      }
      expect(strongest('https://pаypаl.com')!.matched, 'pаypаl');
    });

    test('fautes de frappe', () {
      for (final (url, brand) in [
        ('https://paypall.com', 'paypal'),
        ('https://facebok.com', 'facebook'),
        ('https://gooogle.com', 'google'),
        ('https://whatsap.com', 'whatsapp'),
        ('https://orabnak.net', 'orabank'),
        ('https://westernunoin.com', 'western_union'),
      ]) {
        final match = strongest(url);
        expect(match?.kind, BrandMatchKind.typo, reason: url);
        expect(match?.brand.id, brand, reason: url);
      }
    });

    test('domaine officiel recopié dans un sous-domaine', () {
      final match = strongest(
        'https://paypal.com.verification-compte.example',
      )!;
      expect(match.kind, BrandMatchKind.officialDomainInSubdomain);
      expect(match.brand.id, 'paypal');
      expect(match.matched, 'paypal.com');
      expect(
        strongest('https://www.orange.bf.bonus-gratuit.xyz')!.kind,
        BrandMatchKind.officialDomainInSubdomain,
      );
    });

    test('nom de la marque dans un domaine tiers', () {
      for (final (url, brand) in [
        ('https://paypal-securite.com', 'paypal'),
        ('https://mon-orange-money.com', 'orange'),
        ('https://orangemoney-bonus.net', 'orange'),
        ('https://pay-pal.com', 'paypal'),
        ('https://moov-bonus.com', 'moov_africa'),
        ('https://coris-transfert.com', 'coris_bank'),
        ('https://wa-whatsapp-gratuit.top', 'whatsapp'),
        ('https://dhl-colis.info', 'dhl'),
        ('https://suivi-dhl2024.com', 'dhl'),
      ]) {
        final match = strongest(url);
        expect(match?.kind, BrandMatchKind.keywordInDomain, reason: url);
        expect(match?.brand.id, brand, reason: url);
      }
    });

    test('nom de la marque dans un sous-domaine', () {
      final match = strongest('https://paypal.connexion-securisee.example')!;
      expect(match.kind, BrandMatchKind.keywordInSubdomain);
      expect(match.matched, 'paypal');
      expect(
        strongest('https://orange.cadeau.example')!.kind,
        BrandMatchKind.keywordInSubdomain,
      );
      expect(
        strongest('https://facebook-login.site.example')!.kind,
        BrandMatchKind.keywordInSubdomain,
      );
    });

    test('même nom, autre extension', () {
      for (final url in [
        'https://paypal.bf',
        'https://google.bf',
        'https://orange.ci',
        'https://paypal.blogspot.com',
      ]) {
        expect(
          strongest(url)?.kind,
          BrandMatchKind.sameNameOtherSuffix,
          reason: url,
        );
      }
    });

    test('plusieurs marques dans le même nom, de la plus forte à la plus '
        'faible', () {
      final found = matches('https://paypal.amazon-verification.com');
      expect(found.map((m) => m.brand.id), ['amazon', 'paypal']);
      expect(found.map((m) => m.kind), [
        BrandMatchKind.keywordInDomain,
        BrandMatchKind.keywordInSubdomain,
      ]);
    });

    test('sans rapprochement', () {
      for (final url in [
        'https://lefaso.net',
        'https://www.burkina24.com',
        'https://fr.wikipedia.org',
        'https://www.sidwaya.info',
        'https://orangeraie.fr',
        'https://pineapple.com',
        'https://microwave.example',
        'https://moovie.example',
        'https://email.com',
        'https://visage.com',
        'https://example.com/paypal',
        'https://www.impots.gov.bf',
      ]) {
        expect(matches(url), isEmpty, reason: url);
      }
    });

    test('adresse IP ou suffixe public seul', () {
      expect(matches('http://192.168.1.1'), isEmpty);
      expect(matches('http://[::1]'), isEmpty);
      expect(matches('https://blogspot.com'), isEmpty);
      expect(matches('https://co.uk'), isEmpty);
    });

    test('égalité et affichage', () {
      final a = strongest('https://paypa1.com')!;
      final b = strongest('https://paypa1.com')!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(strongest('https://paypall.com')));
      expect(a.toString(), 'BrandMatch(paypal, lookalike)');
    });
  });

  group('marques citées dans un texte', () {
    test('mots-clés et noms isolés', () {
      Set<String> ids(String text) =>
          _matcher.brandsMentionedIn(text).map((b) => b.id).toSet();
      expect(ids('/connexion/paypal/verification'), {'paypal'});
      expect(ids('Votre colis DHL est en attente'), {'dhl'});
      expect(ids('Recharge ton compte Orange Money'), {'orange'});
      expect(ids('/mypaypalaccount'), {'paypal'});
      expect(ids('orangeraie et pineapple'), isEmpty);
      expect(ids('Bonjour, rendez-vous demain'), isEmpty);
    });
  });

  group('registre personnalisé', () {
    test('marques et liste de suffixes injectées', () {
      const brand = Brand(
        id: 'demo',
        name: 'Démo',
        category: BrandCategory.tech,
        domains: ['demo.test'],
        keywords: ['demoapp'],
        tokens: ['demo'],
        sources: [
          BrandSource(
            kind: BrandSourceKind.wikidata,
            url: 'https://www.wikidata.org/wiki/Q1',
            domains: ['demo.test'],
          ),
        ],
        verifiedOn: '2026-01-01',
      );
      final registry = BrandRegistry(
        [brand],
        suffixes: PublicSuffixList.fromRules(
          icannRules: 'test',
          privateRules: '',
        ),
      );
      final matcher = BrandMatcher(registry: registry);
      expect(matcher.registry, same(registry));
      final psl = PublicSuffixList.fromRules(
        icannRules: 'test',
        privateRules: '',
      );
      expect(
        matcher.matchHost('demo-bonus.test', psl.lookup('demo-bonus.test')!),
        [
          const BrandMatch(
            brand,
            BrandMatchKind.keywordInDomain,
            matched: 'demo-bonus',
          ),
        ],
      );
      expect(matcher.matchHost('test', psl.lookup('test')!), isEmpty);
    });
  });
}
