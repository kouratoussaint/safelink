import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/app/app.dart';
import 'package:safelink/core/licenses.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/features/quick/quick_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const SafeLinkApp(),
    ),
  );
}

/// Point d'entrée du panneau rapide (`QuickCheckActivity`, ADR 0015) : un
/// second moteur Flutter, ouvert par la bulle, la tuile du volet ou la
/// notification de la bulle.
@pragma('vm:entry-point')
Future<void> quickCheckMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const QuickCheckApp(),
    ),
  );
}
