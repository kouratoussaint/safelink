import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/core/settings/preferences.dart';

/// Mode expert : vrai si l'utilisateur veut voir toutes les explications,
/// les sources et les détails techniques sans les déplier.
final expertModeProvider = NotifierProvider<ExpertModeController, bool>(
  ExpertModeController.new,
);

/// Lit et enregistre le mode expert (désactivé par défaut : l'application
/// parle d'abord par images et par mots simples).
class ExpertModeController extends Notifier<bool> {
  /// Clé de stockage dans les préférences.
  static const storageKey = 'expert_mode';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(storageKey) ?? false;

  /// Active ou désactive le mode expert.
  Future<void> select({required bool enabled}) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(storageKey, enabled);
  }
}
