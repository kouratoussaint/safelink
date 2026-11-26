import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:safelink/app/app.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Taille de référence des maquettes (cahier des charges, §4).
const referenceSize = Size(393, 852);

/// Démarre l'application complète dans un environnement de test isolé.
///
/// [preferences] initialise les réglages enregistrés, [size] la taille de
/// l'écran et [textScale] le grossissement du texte (accessibilité).
Future<SharedPreferences> pumpSafeLinkApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
  Size size = referenceSize,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  PackageInfo.setMockInitialValues(
    appName: 'SafeLink',
    packageName: 'com.safelink.fasosoft',
    version: '0.0.1',
    buildNumber: '1',
    buildSignature: '',
  );
  final prefs = await SharedPreferences.getInstance();

  tester.view
    ..physicalSize = size * tester.view.devicePixelRatio
    ..platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SafeLinkApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// Trouve le titre de la barre d'application courante.
Finder appBarTitle(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// Touche une destination de la barre de navigation par son libellé.
Future<void> tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
