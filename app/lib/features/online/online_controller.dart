import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/features/online/online_checker.dart';

/// Choix de l'utilisateur pour la vérification en ligne.
enum OnlineChoice {
  /// Pas encore choisi : rien n'est envoyé.
  undecided,

  /// Les noms de sites sont vérifiés en ligne.
  enabled,

  /// Aucune vérification en ligne.
  disabled,
}

/// Choix pour la vérification en ligne, conservé dans les préférences.
final NotifierProvider<OnlineChoiceController, OnlineChoice>
onlineChoiceProvider = NotifierProvider(OnlineChoiceController.new);

/// Lit et enregistre le choix pour la vérification en ligne.
class OnlineChoiceController extends Notifier<OnlineChoice> {
  /// Clé de stockage dans les préférences.
  static const storageKey = 'online_checks';

  @override
  OnlineChoice build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return OnlineChoice.values.firstWhere(
      (choice) => choice.name == stored && choice != OnlineChoice.undecided,
      orElse: () => OnlineChoice.undecided,
    );
  }

  /// Active ou désactive la vérification en ligne.
  Future<void> select({required bool enabled}) async {
    final choice = enabled ? OnlineChoice.enabled : OnlineChoice.disabled;
    state = choice;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, choice.name);
  }
}

/// Vérificateur en ligne, partagé pendant la session (son cache ne vit
/// qu'en mémoire) ; remplacé dans les tests.
final Provider<OnlineChecker> onlineCheckerProvider = Provider(
  (ref) => OnlineChecker(),
);
