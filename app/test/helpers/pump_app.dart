import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:safelink/app/app.dart';
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/page_preview.dart';
import 'package:safelink/features/online/short_links.dart';
import 'package:safelink/features/share/share_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_online.dart';
import 'fake_share.dart';
import 'fake_speaker.dart';

/// Taille de référence des maquettes (cahier des charges, §4).
const referenceSize = Size(393, 852);

/// Démarre l'application complète dans un environnement de test isolé.
///
/// [preferences] initialise les réglages enregistrés, [size] la taille de
/// l'écran et [textScale] le grossissement du texte (accessibilité). Sauf
/// si [onboarded] est faux, la présentation de première ouverture est
/// considérée comme déjà vue. L'analyse se fait par défaut sans isolat, de
/// façon synchrone : [analysisService] permet de la remplacer ; les
/// vérifications en ligne sont simulées ([onlineChecker], sans connexion par
/// défaut) et désactivées sauf choix contraire ([online] ; `null` : rien
/// d'enregistré, comme à l'installation, donc activées) ; les services
/// Google sont désactivés sauf si [googleKey] est fournie. Le mode expert
/// est actif sauf si [expert] est faux : les tests de contenu voient ainsi
/// toutes les explications ; la lecture à voix haute est simulée
/// ([speaker]). L'historique est gardé en mémoire ([historyBackend]). Les
/// partages venus d'autres applications sont simulés ([shareSource], aucun
/// par défaut).
Future<SharedPreferences> pumpSafeLinkApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
  Size size = referenceSize,
  double textScale = 1,
  bool onboarded = true,
  OnlineChoice? online = OnlineChoice.disabled,
  AnalysisService? analysisService,
  OnlineChecker? onlineChecker,
  String googleKey = '',
  PagePreviewClient? pagePreviewClient,
  bool expert = true,
  Speaker? speaker,
  ShortLinkResolver? shortLinks,
  HistoryBackend? historyBackend,
  ShareSource? shareSource,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) OnboardingController.storageKey: true,
    if (online != null) OnlineChoiceController.storageKey: online.name,
    if (expert) ExpertModeController.storageKey: true,
    ...preferences,
  });
  PackageInfo.setMockInitialValues(
    appName: 'SafeLink',
    packageName: 'com.fasosoft.safelink',
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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analysisServiceProvider.overrideWithValue(
          analysisService ??
              DeviceAnalysisService(
                checker: onlineChecker ?? offlineChecker(),
                shortLinks: shortLinks,
                useIsolates: false,
              ),
        ),
        googleApiKeyProvider.overrideWithValue(googleKey),
        speakerProvider.overrideWithValue(speaker ?? FakeSpeaker()),
        pagePreviewClientProvider.overrideWithValue(pagePreviewClient),
        historyBackendProvider.overrideWithValue(
          historyBackend ?? MemoryHistoryBackend(),
        ),
        shareSourceProvider.overrideWithValue(shareSource ?? FakeShareSource()),
      ],
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

/// Ouvre « À propos » depuis les paramètres, en faisant défiler l'écran.
Future<void> openAbout(WidgetTester tester) async {
  await tapDestination(tester, 'Paramètres');
  await tester.scrollUntilVisible(find.text('À propos de SafeLink'), 200);
  await tester.tap(find.text('À propos de SafeLink'));
  await tester.pumpAndSettle();
}
