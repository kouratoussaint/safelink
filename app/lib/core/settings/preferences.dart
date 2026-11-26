import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accès aux préférences locales (réglages non sensibles uniquement).
///
/// L'instance est chargée dans `main()` puis injectée par une surcharge du
/// `ProviderScope` ; les tests injectent une instance en mémoire.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider doit être surchargé au démarrage.',
  ),
);
