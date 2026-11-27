import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/core/settings/preferences.dart';

/// Vrai une fois la présentation de première ouverture terminée.
final onboardingDoneProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

/// Lit et enregistre la fin de la présentation.
class OnboardingController extends Notifier<bool> {
  /// Clé de stockage dans les préférences.
  static const storageKey = 'onboarding_done';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(storageKey) ?? false;

  /// Marque la présentation comme terminée.
  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(storageKey, true);
  }
}
