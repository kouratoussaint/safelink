import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;
import 'package:safelink/core/settings/expert_mode_controller.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_controller.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/quick/quick_app.dart';
import 'package:safelink/features/quick/quick_platform.dart';
import 'package:safelink/features/share/shared_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_online.dart';
import 'fake_quick.dart';
import 'fake_speaker.dart';
import 'pump_app.dart' show referenceSize;

/// Démarre le panneau rapide seul, comme `quickCheckMain`, avec le texte
/// copié [copied] (rien de lu si `null`).
///
/// Comme pour l'application (`pumpSafeLinkApp`) : vérification en ligne
/// simulée et désactivée sauf choix contraire, historique en mémoire,
/// lecture à voix haute simulée. Le mode simple est actif sauf si
/// [expert] : c'est ce que voient la plupart des utilisateurs. Sans
/// [settle], les animations ne sont pas attendues (indicateur de lecture).
Future<FakeQuickPlatform> pumpQuickPanel(
  WidgetTester tester, {
  SharedContent? copied,
  Map<String, Object> preferences = const {},
  Size size = referenceSize,
  double textScale = 1,
  OnlineChoice? online = OnlineChoice.disabled,
  OnlineChecker? onlineChecker,
  bool expert = false,
  HistoryBackend? historyBackend,
  Speaker? speaker,
  FakeQuickPlatform? platform,
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (online != null) OnlineChoiceController.storageKey: online.name,
    if (expert) ExpertModeController.storageKey: true,
    ...preferences,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = size * tester.view.devicePixelRatio
    ..platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final quick = platform ?? FakeQuickPlatform([?copied]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analysisServiceProvider.overrideWithValue(
          DeviceAnalysisService(
            checker: onlineChecker ?? offlineChecker(),
            useIsolates: false,
          ),
        ),
        googleApiKeyProvider.overrideWithValue(''),
        speakerProvider.overrideWithValue(speaker ?? FakeSpeaker()),
        pagePreviewClientProvider.overrideWithValue(null),
        historyBackendProvider.overrideWithValue(
          historyBackend ?? MemoryHistoryBackend(),
        ),
        quickPlatformProvider.overrideWithValue(quick),
      ],
      child: const QuickCheckApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
  return quick;
}
