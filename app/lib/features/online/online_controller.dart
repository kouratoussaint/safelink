import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/page_preview.dart';
import 'package:safelink/features/online/safe_browsing.dart';

/// Choix de l'utilisateur pour la vérification en ligne.
enum OnlineChoice {
  /// Les liens sont vérifiés en ligne (par défaut, ADR 0013).
  enabled,

  /// Aucune vérification en ligne : analyse sur le téléphone seulement.
  disabled,
}

/// Choix pour la vérification en ligne, conservé dans les préférences.
final NotifierProvider<OnlineChoiceController, OnlineChoice>
onlineChoiceProvider = NotifierProvider(OnlineChoiceController.new);

/// Lit et enregistre le choix pour la vérification en ligne.
class OnlineChoiceController extends Notifier<OnlineChoice> {
  /// Clé de stockage dans les préférences. Un refus enregistré est
  /// toujours respecté.
  static const storageKey = 'online_checks_v2';

  /// Activée par défaut (décision du porteur, ADR 0013) : seul un refus
  /// explicite la coupe.
  @override
  OnlineChoice build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return stored == OnlineChoice.disabled.name
        ? OnlineChoice.disabled
        : OnlineChoice.enabled;
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

/// Clé d'API Google, fournie à la compilation
/// (`--dart-define=SAFELINK_GOOGLE_API_KEY=…`, secret GitHub du même nom).
/// Vide : Google Safe Browsing et la photo des pages sont désactivés.
const googleApiKey = String.fromEnvironment('SAFELINK_GOOGLE_API_KEY');

/// Clé d'API Google de cette version ; remplacée dans les tests.
final Provider<String> googleApiKeyProvider = Provider((ref) => googleApiKey);

/// Vrai si les services Google sont disponibles dans cette version.
final Provider<bool> googleEnabledProvider = Provider(
  (ref) => ref.watch(googleApiKeyProvider).isNotEmpty,
);

/// Client Google Safe Browsing, s'il y a une clé.
final Provider<SafeBrowsingClient?> safeBrowsingClientProvider = Provider((
  ref,
) {
  final key = ref.watch(googleApiKeyProvider);
  return key.isEmpty ? null : SafeBrowsingClient(apiKey: key);
});

/// Client de photo des pages, s'il y a une clé.
final Provider<PagePreviewClient?> pagePreviewClientProvider = Provider((ref) {
  final key = ref.watch(googleApiKeyProvider);
  return key.isEmpty ? null : PagePreviewClient(apiKey: key);
});

/// Vérificateur en ligne, partagé pendant la session (son cache ne vit
/// qu'en mémoire) ; remplacé dans les tests.
final Provider<OnlineChecker> onlineCheckerProvider = Provider(
  (ref) => OnlineChecker(safeBrowsing: ref.watch(safeBrowsingClientProvider)),
);
