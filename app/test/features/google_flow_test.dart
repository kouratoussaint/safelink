import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';

import '../helpers/fake_google.dart';
import '../helpers/fake_online.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;
import 'history_flow_test.dart' as history;

OnlineChecker googleChecker({Map<String, String> threats = const {}}) =>
    OnlineChecker(
      dns: FakeDohTransport(),
      json: FakeJsonTransport(
        registeredOn: {'lefaso.net': DateTime.utc(2003, 8, 25)},
      ),
      safeBrowsing: fakeSafeBrowsing(threats: threats),
    );

Future<void> pumpGoogle(
  WidgetTester tester, {
  OnlineChecker? checker,
  String? finalUrl,
  bool unreachable = false,
  OnlineChoice online = OnlineChoice.enabled,
}) => pumpSafeLinkApp(
  tester,
  online: online,
  googleKey: 'test-key',
  onlineChecker: checker ?? googleChecker(),
  pagePreviewClient: fakePreview(finalUrl: finalUrl, unreachable: unreachable),
);

void main() {
  testWidgets('photo de la page prise automatiquement', (tester) async {
    await pumpGoogle(tester);
    await history.analyzeLink(tester, 'https://lefaso.net/actualites');
    await flow.scrollTo(tester, find.text('Aperçu de la page'));
    expect(
      find.bySemanticsLabel('Photo de la page, prise par Google'),
      findsOneWidget,
    );
    expect(
      find.text('Photo prise par Google : vous voyez la page sans l’ouvrir.'),
      findsOneWidget,
    );
    expect(find.text('Faux site probable'), findsNothing);
    expect(find.text('Ce lien mène en réalité à :'), findsNothing);
  });

  testWidgets('redirection : vraie destination et nouvelle vérification', (
    tester,
  ) async {
    await pumpGoogle(tester, finalUrl: 'https://faux-orange.xyz/login');
    await history.analyzeLink(tester, 'https://lefaso.net/sortie');
    await flow.scrollTo(tester, find.text('Ce lien mène en réalité à :'));
    // Barre d'adresse de la photo (la page réellement photographiée) et
    // destination sous la photo.
    expect(find.text('faux-orange.xyz'), findsNWidgets(2));
    await tester.tap(flow.button('Vérifier cette destination'));
    await tester.pumpAndSettle();
    expect(find.text('https://faux-orange.xyz/login'), findsOneWidget);
  });

  testWidgets('lien avec un code personnel : photo seulement sur demande', (
    tester,
  ) async {
    await pumpGoogle(tester);
    await history.analyzeLink(
      tester,
      'https://lefaso.net/reset?token=abcdefghijklmnop123456',
    );
    await flow.scrollTo(tester, find.textContaining('code personnel'));
    expect(
      find.bySemanticsLabel('Photo de la page, prise par Google'),
      findsNothing,
    );
    await tester.tap(flow.button('Prendre la photo quand même'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Photo de la page, prise par Google'),
      findsOneWidget,
    );
  });

  testWidgets('page fermée : message clair', (tester) async {
    await pumpGoogle(tester, unreachable: true);
    await history.analyzeLink(tester, 'https://lefaso.net/');
    await flow.scrollTo(
      tester,
      find.textContaining('La page ne s’affiche pas'),
    );
    expect(find.text('Réessayer'), findsWidgets);
  });

  testWidgets('signalé par Google : menace connue, attribution', (
    tester,
  ) async {
    await pumpGoogle(
      tester,
      checker: googleChecker(threats: {'lefaso.net/': 'SOCIAL_ENGINEERING'}),
    );
    await history.analyzeLink(tester, 'https://lefaso.net/');
    expect(find.text('Menace connue détectée'), findsOneWidget);
    expect(find.text('Faux site probable'), findsOneWidget);
    await flow.scrollTo(tester, find.text('Google Safe Browsing'));
    expect(find.text('Signalé comme dangereux'), findsOneWidget);
    await flow.scrollTo(
      tester,
      find.textContaining('Avertissement fourni par Google'),
    );
  });

  testWidgets('sans accord : ni photo ni Google', (tester) async {
    await pumpGoogle(tester, online: OnlineChoice.disabled);
    await history.analyzeLink(tester, 'https://lefaso.net/');
    expect(find.text('Aperçu de la page'), findsNothing);
  });

  testWidgets('textes d’accord : Google nommé', (tester) async {
    await pumpGoogle(tester, online: OnlineChoice.undecided);
    await history.analyzeLink(tester, 'https://lefaso.net/');
    expect(
      find.textContaining('et à Google une photo de la page'),
      findsOneWidget,
    );
    await tapDestination(tester, 'Paramètres');
    await tester.scrollUntilVisible(
      find.textContaining('Google reçoit le lien'),
      200,
    );
  });
}
