import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_google.dart';
import '../helpers/fake_online.dart';
import '../helpers/fake_short_links.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;
import 'history_flow_test.dart' as history;

const short = 'https://bit.ly/abc';
const trap = 'https://faux-orange.xyz/login';

Future<void> pumpShort(
  WidgetTester tester, {
  bool offline = false,
  bool expert = false,
}) => pumpSafeLinkApp(
  tester,
  expert: expert,
  online: OnlineChoice.enabled,
  onlineChecker: fakeChecker(
    dns: FakeDohTransport(blockedByQuad9: {'faux-orange.xyz'}),
  ),
  shortLinks: fakeShortLinks({short: trap}, offline: offline),
);

void main() {
  test('service : la destination est vérifiée et aggrave le niveau', () async {
    final service = DeviceAnalysisService(
      checker: fakeChecker(
        dns: FakeDohTransport(blockedByQuad9: {'faux-orange.xyz'}),
      ),
      shortLinks: fakeShortLinks({short: trap}),
      useIsolates: false,
    );
    final outcome = await service.analyze(
      AnalysisRequest(AnalysisKind.link, short),
      online: true,
    ) as LinkOutcome;
    expect(outcome.online, OnlineStatus.done);
    expect(outcome.destination?.url?.href, trap);
    expect(outcome.destination?.verdict, UrlVerdict.knownThreat);
    expect(outcome.ownLevel, isNot(RiskLevel.danger));
    expect(outcome.level, RiskLevel.danger);
  });

  test('service : sans accord, aucun raccourcisseur contacté', () async {
    final resolver = fakeShortLinks({short: trap});
    final outcome = await DeviceAnalysisService(
      checker: fakeChecker(),
      shortLinks: resolver,
      useIsolates: false,
    ).analyze(AnalysisRequest(AnalysisKind.link, short));
    expect(outcome.destinations, isEmpty);
    expect(
      await resolver.resolve(UrlParser().parse(short) as ParsedUrl),
      isNotNull,
    );
  });

  testWidgets('lien raccourci : vraie destination et danger en grand', (
    tester,
  ) async {
    await pumpShort(tester);
    await history.analyzeLink(tester, short);
    // En grand, et sur la carte de la destination.
    expect(find.text('Danger !'), findsWidgets);
    expect(
      find.text('Ce lien raccourci mène à un site dangereux. Ne l’ouvrez pas.'),
      findsOneWidget,
    );
    await flow.scrollTo(tester, find.text('Ce lien raccourci mène à :'));
    expect(
      find.bySemanticsLabel('Vraie destination : faux-orange.xyz'),
      findsOneWidget,
    );
    expect(find.text('Menace connue détectée'), findsWidgets);

    await flow.scrollTo(tester, find.text('Voir ce site en détail'));
    await tester.tap(flow.button('Voir ce site en détail'));
    await tester.pumpAndSettle();
    expect(find.text('Danger !'), findsOneWidget);
    expect(find.text('Ce lien raccourci mène à :'), findsNothing);
  });

  testWidgets('gestes de la destination quand elle est plus grave', (
    tester,
  ) async {
    await pumpShort(tester);
    await history.analyzeLink(tester, short);
    await flow.scrollTo(tester, find.text('Ne touchez pas le lien'));
    await flow.scrollTo(tester, find.text('Voir les explications'));
    expect(find.text('Ouvrez seulement si vous l’attendiez'), findsNothing);
  });

  testWidgets('service muet : on le dit, sans inventer', (tester) async {
    await pumpShort(tester, offline: true);
    await history.analyzeLink(tester, short);
    await flow.scrollTo(
      tester,
      find.textContaining('Impossible de savoir où mène ce lien raccourci'),
    );
    expect(find.text('Danger !'), findsNothing);
  });

  testWidgets('message : le lien raccourci montre où il mène', (tester) async {
    await pumpShort(tester);
    await history.analyzeMessage(
      tester,
      'Bonjour, voici votre colis à récupérer : $short',
    );
    expect(find.text('Danger !'), findsOneWidget);
    final tile = find.textContaining('Mène à faux-orange.xyz');
    await flow.scrollTo(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await flow.scrollTo(tester, find.text('Ce lien raccourci mène à :'));
    expect(find.text('Danger !'), findsWidgets);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('carte de destination ($theme) : règles d’accessibilité', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
        preferences: {ThemeModeController.storageKey: theme},
        onlineChecker: fakeChecker(
          dns: FakeDohTransport(blockedByQuad9: {'faux-orange.xyz'}),
        ),
        shortLinks: fakeShortLinks({short: trap}),
      );
      await history.analyzeLink(tester, short);
      await flow.scrollTo(tester, find.text('Voir ce site en détail'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('lien d’application : photo de la page du Play Store', (
    tester,
  ) async {
    const play =
        'https://play.google.com/store/apps/details?id=com.orange.myorange.ocm';
    final preview = fakePreview();
    await pumpSafeLinkApp(
      tester,
      expert: false,
      online: OnlineChoice.enabled,
      googleKey: 'test-key',
      onlineChecker: OnlineChecker(
        dns: FakeDohTransport(),
        json: FakeJsonTransport(),
        safeBrowsing: fakeSafeBrowsing(),
      ),
      pagePreviewClient: preview,
      shortLinks: fakeShortLinks({
        'https://onelink.to/nn64xw':
            'market://details?id=com.orange.myorange.ocm',
      }),
    );
    await history.analyzeLink(tester, 'https://onelink.to/nn64xw');
    await flow.scrollTo(tester, find.text('Ce lien raccourci mène à :'));
    expect(
      find.bySemanticsLabel('Vraie destination : google.com'),
      findsOneWidget,
    );
    await flow.scrollTo(tester, find.text('Aperçu de la page'));
    expect(
      find.bySemanticsLabel('Photo de la page, prise par Google'),
      findsOneWidget,
    );
    // Google photographie la page du Play Store, pas le lien qui l'ouvre.
    final (uri, _) = (preview.http as FakeHttpTransport).requests.single;
    expect(uri.queryParameters['url'], play);
  });

  group('pas de connexion', () {
    testWidgets('lien : bandeau visible, « Réessayer » relance', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(find.text('Pas de connexion'), findsOneWidget);
      expect(
        find.textContaining('Vérifié seulement sur le téléphone'),
        findsOneWidget,
      );
      await tester.tap(flow.button('Réessayer').first);
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion'), findsOneWidget);
    });

    testWidgets('message avec lien : bandeau visible', (tester) async {
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: OnlineChoice.enabled,
      );
      await history.analyzeMessage(
        tester,
        'Votre colis vous attend : https://lefaso.net/colis',
      );
      expect(find.text('Pas de connexion'), findsOneWidget);
    });

    testWidgets('connexion revenue : pas de bandeau', (tester) async {
      await pumpSafeLinkApp(
        tester,
        expert: false,
        online: null,
        onlineChecker: fakeChecker(),
      );
      await history.analyzeLink(tester, 'https://lefaso.net/');
      expect(find.text('Pas de connexion'), findsNothing);
    });
  });
}
