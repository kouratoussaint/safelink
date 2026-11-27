import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink_engine/safelink_engine.dart';

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
    expect(find.text('Danger !'), findsWidgets);
    expect(
      find.text('Ce lien raccourci mène à un site dangereux. Ne l’ouvrez pas.'),
      findsOneWidget,
    );
    await flow.scrollTo(tester, find.text('Ce lien raccourci mène à :'));
    expect(
      find.bySemanticsLabel('Vraie destination : faux-orange.xyz'),
      findsOneWidget,
    );
    expect(find.text('Menace connue détectée'), findsWidgets);

    await flow.scrollTo(tester, find.text('Voir ce site en détail'));
    await tester.tap(flow.button('Voir ce site en détail'));
    await tester.pumpAndSettle();
    expect(find.text('Danger !'), findsOneWidget);
    expect(find.text('Ce lien raccourci mène à :'), findsNothing);
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
    expect(find.text('Danger !'), findsNothing);
  });

  testWidgets('message : le lien raccourci montre où il mène', (tester) async {
    await pumpShort(tester);
    await history.analyzeMessage(
      tester,
      'Bonjour, voici votre colis à récupérer : $short',
    );
    expect(find.text('Danger !'), findsOneWidget);
    final tile = find.textContaining('Mène à faux-orange.xyz');
    await flow.scrollTo(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await flow.scrollTo(tester, find.text('Ce lien raccourci mène à :'));
    expect(find.text('Danger !'), findsWidgets);
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
}
