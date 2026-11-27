import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/shell.dart';

import '../helpers/pump_app.dart';

const exitMessage = 'Appuyez de nouveau sur Retour pour quitter SafeLink';

/// Simule le bouton Retour d'Android : même message que celui envoyé par le
/// système à Flutter.
Future<void> pressBack(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    const MethodCall('popRoute'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Écran affiché : titre de la barre d'application visible.
String currentTitle(WidgetTester tester) {
  final titles = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(Text),
  );
  return tester.widgetList<Text>(titles.hitTestable()).first.data ?? '';
}

void main() {
  late List<String> exits;

  setUp(() => exits = []);

  Future<void> pump(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpSafeLinkApp(tester);
  }

  testWidgets('Retour ferme d’abord l’écran ouvert dans l’onglet', (
    tester,
  ) async {
    await pump(tester);
    await openAbout(tester);
    expect(currentTitle(tester), 'À propos');

    await pressBack(tester);
    expect(currentTitle(tester), 'Paramètres');
    expect(exits, isEmpty);
  });

  testWidgets('Retour remonte les onglets visités jusqu’à l’Accueil', (
    tester,
  ) async {
    await pump(tester);
    await tapDestination(tester, 'Historique');
    await tapDestination(tester, 'Conseils');
    await tapDestination(tester, 'Paramètres');

    await pressBack(tester);
    expect(currentTitle(tester), 'Conseils');
    await pressBack(tester);
    expect(currentTitle(tester), 'Historique');
    await pressBack(tester);
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('l’aide ouverte depuis l’Accueil revient à l’Accueil', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Aide'));
    await tester.pumpAndSettle();
    expect(currentTitle(tester), 'Aide');

    await pressBack(tester);
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
  });

  testWidgets('un écran ouvert puis un autre onglet : retours successifs', (
    tester,
  ) async {
    await pump(tester);
    await openAbout(tester);
    await tapDestination(tester, 'Conseils');

    await pressBack(tester);
    expect(currentTitle(tester), 'À propos');
    await pressBack(tester);
    expect(currentTitle(tester), 'Paramètres');
    await pressBack(tester);
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('sur l’Accueil, deux appuis rapprochés ferment l’application', (
    tester,
  ) async {
    await pump(tester);

    await pressBack(tester);
    expect(find.text(exitMessage), findsOneWidget);
    expect(exits, isEmpty, reason: 'le premier appui ne ferme pas');

    await tester.pump(const Duration(milliseconds: 800));
    await pressBack(tester);
    expect(exits, hasLength(1), reason: 'le second appui ferme');

    await tester.pump(AppShell.exitConfirmationDelay);
  });

  testWidgets('un second appui trop tardif ne ferme pas l’application', (
    tester,
  ) async {
    await pump(tester);

    await pressBack(tester);
    await tester.pump(
      AppShell.exitConfirmationDelay + const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();

    await pressBack(tester);
    expect(exits, isEmpty);
    expect(find.text(exitMessage), findsOneWidget, reason: 'message réaffiché');

    await tester.pump(AppShell.exitConfirmationDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('changer d’onglet annule la demande de fermeture', (
    tester,
  ) async {
    await pump(tester);

    await pressBack(tester);
    await tapDestination(tester, 'Conseils');
    await pressBack(tester);
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
    await pressBack(tester);
    expect(exits, isEmpty, reason: 'il faut de nouveau deux appuis');

    await tester.pump(AppShell.exitConfirmationDelay);
    await tester.pumpAndSettle();
  });
}
