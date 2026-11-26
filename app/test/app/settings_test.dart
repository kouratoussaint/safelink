import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';

import '../helpers/pump_app.dart';

Brightness currentBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NavigationBar))).brightness;

void main() {
  testWidgets('le thème choisi est appliqué et enregistré', (tester) async {
    final prefs = await pumpSafeLinkApp(tester);
    expect(currentBrightness(tester), Brightness.light);

    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(currentBrightness(tester), Brightness.dark);
    expect(prefs.getString(ThemeModeController.storageKey), 'dark');

    await tester.tap(find.text('Clair'));
    await tester.pumpAndSettle();
    expect(currentBrightness(tester), Brightness.light);
    expect(prefs.getString(ThemeModeController.storageKey), 'light');
  });

  testWidgets('le thème enregistré est restauré au démarrage', (tester) async {
    await pumpSafeLinkApp(
      tester,
      preferences: {ThemeModeController.storageKey: 'dark'},
    );
    expect(currentBrightness(tester), Brightness.dark);
  });

  testWidgets('une valeur enregistrée inconnue revient au thème système', (
    tester,
  ) async {
    await pumpSafeLinkApp(
      tester,
      preferences: {ThemeModeController.storageKey: 'inconnu'},
    );
    await tapDestination(tester, 'Paramètres');
    final group = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(group.groupValue, ThemeMode.system);
  });

  testWidgets('« À propos » affiche version, licence et dépôt', (tester) async {
    await pumpSafeLinkApp(tester);
    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('À propos de SafeLink'));
    await tester.pumpAndSettle();

    expect(appBarTitle('À propos'), findsOneWidget);
    expect(find.text('0.0.1 (1)'), findsOneWidget);
    expect(find.text('Build local'), findsOneWidget);
    expect(find.text('GPL-3.0-or-later (logiciel libre)'), findsOneWidget);
    expect(
      find.text('https://github.com/kouratoussaint/safelink'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ne garantit jamais', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('l’adresse du dépôt est copiée, jamais ouverte', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copied.add(args['text']! as String);
        }
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
    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('À propos de SafeLink'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Copier l'adresse du code source"));
    await tester.pumpAndSettle();

    expect(copied, ['https://github.com/kouratoussaint/safelink']);
    expect(find.text('Adresse copiée.'), findsOneWidget);
  });

  testWidgets('la page des licences s’ouvre', (tester) async {
    await pumpSafeLinkApp(tester);
    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('À propos de SafeLink'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Licences des composants'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Licences des composants'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
