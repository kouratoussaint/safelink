import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/core/settings/preferences.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/history/history_store.dart';

/// Choix de l'utilisateur pour l'historique.
enum HistoryChoice {
  /// Pas encore choisi : rien n'est enregistré.
  undecided,

  /// Les vérifications sont enregistrées.
  enabled,

  /// Les vérifications ne sont pas enregistrées.
  disabled,
}

/// Choix pour l'historique, conservé dans les préférences.
final historyChoiceProvider =
    NotifierProvider<HistoryChoiceController, HistoryChoice>(
      HistoryChoiceController.new,
    );

/// Lit et enregistre le choix pour l'historique.
class HistoryChoiceController extends Notifier<HistoryChoice> {
  /// Clé de stockage dans les préférences.
  static const storageKey = 'history_choice';

  @override
  HistoryChoice build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return HistoryChoice.values.firstWhere(
      (choice) => choice.name == stored && choice != HistoryChoice.undecided,
      orElse: () => HistoryChoice.undecided,
    );
  }

  /// Active ou désactive l'historique.
  Future<void> select({required bool enabled}) async {
    final choice = enabled ? HistoryChoice.enabled : HistoryChoice.disabled;
    state = choice;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, choice.name);
  }
}

/// Accès au stockage ; remplacé dans les tests.
final Provider<HistoryBackend> historyBackendProvider = Provider(
  (ref) => SqfliteHistoryBackend(),
);

/// Vérifications enregistrées, de la plus récente à la plus ancienne.
final historyProvider =
    AsyncNotifierProvider<HistoryController, List<HistoryEntry>>(
      HistoryController.new,
      retry: (_, _) => null,
    );

/// Lit et modifie l'historique.
///
/// Le panneau rapide (bulle, tuile) a son propre moteur Flutter et peut
/// enregistrer une vérification pendant que l'application reste ouverte en
/// arrière-plan : au retour dans SafeLink, l'historique est relu s'il a
/// changé.
class HistoryController extends AsyncNotifier<List<HistoryEntry>> {
  HistoryBackend get _backend => ref.read(historyBackendProvider);

  /// Empreinte de l'historique lu ; `null` : aucun historique.
  String? _stamp;

  @override
  Future<List<HistoryEntry>> build() async {
    final listener = AppLifecycleListener(
      onResume: () => unawaited(_reloadIfChanged()),
    );
    ref.onDispose(listener.dispose);
    final backend = ref.watch(historyBackendProvider);
    _stamp = null;
    // Tant que rien n'a été enregistré, aucun fichier n'est créé.
    if (!await backend.exists()) return const [];
    final store = await backend.open();
    _stamp = await store.stamp();
    return await store.entries();
  }

  Future<void> _reloadIfChanged() async {
    final backend = _backend;
    if (!await backend.exists()) return;
    final stamp = await (await backend.open()).stamp();
    if (ref.mounted && stamp != _stamp) ref.invalidateSelf();
  }

  Future<void> _change(Future<void> Function(HistoryStore store) action) async {
    final store = await _backend.open();
    await action(store);
    _stamp = await store.stamp();
    state = AsyncData(await store.entries());
  }

  /// Enregistre [entry].
  Future<void> add(HistoryEntry entry) => _change((store) => store.add(entry));

  /// Conserve ou efface le contenu complet de [id].
  Future<void> setContent(String id, String? content) =>
      _change((store) => store.setContent(id, content));

  /// Supprime la vérification [id].
  Future<void> delete(String id) => _change((store) => store.delete(id));

  /// Supprime toutes les vérifications.
  Future<void> clear() async {
    if (!await _backend.exists()) return;
    await _change((store) => store.clear());
  }
}

/// Enregistrement dans l'historique du résultat d'une demande d'analyse.
///
/// Si l'historique est activé, le résultat est enregistré une fois, sans
/// contenu complet. L'état vaut la vérification enregistrée, ou `null`.
// Le type de famille n'est pas exporté par Riverpod.
// ignore: specify_nonobvious_property_types
final historyRecordProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryRecorder, HistoryEntry?, AnalysisRequest>(
      HistoryRecorder.new,
      retry: (_, _) => null,
    );

/// Enregistre, retire ou complète la vérification d'une demande.
class HistoryRecorder extends AsyncNotifier<HistoryEntry?> {
  /// Crée l'enregistreur de [request].
  new(this.request);

  /// Demande analysée.
  final AnalysisRequest request;

  String? _id;

  @override
  Future<HistoryEntry?> build() async {
    final outcome = await ref.watch(analysisProvider(request).future);
    if (request.example) return null;
    if (ref.read(historyChoiceProvider) != HistoryChoice.enabled) return null;
    return await _save(outcome);
  }

  Future<HistoryEntry> _save(AnalysisOutcome outcome) async {
    // Une nouvelle analyse de la même demande (vérification en ligne
    // activée entre-temps) remplace l'enregistrement, contenu gardé compris.
    final entry = HistoryEntry.fromOutcome(
      _id ??= request.historyId ?? newHistoryId(),
      outcome,
    ).withContent(state.value?.content);
    await ref.read(historyProvider.notifier).add(entry);
    return entry;
  }

  /// Enregistre maintenant (après activation de l'historique).
  Future<void> save() async {
    if (state.value != null) return;
    final outcome = await ref.read(analysisProvider(request).future);
    final entry = await _save(outcome);
    if (ref.mounted) state = AsyncData(entry);
  }

  /// Retire la vérification de l'historique.
  Future<void> remove() async {
    final entry = state.value;
    if (entry == null) return;
    await ref.read(historyProvider.notifier).delete(entry.id);
    if (ref.mounted) state = const AsyncData(null);
  }

  /// Conserve ou non le lien complet ou le texte du message.
  Future<void> keepContent({required bool keep}) async {
    final entry = state.value;
    if (entry == null) return;
    final content = keep ? request.text.trim() : null;
    await ref.read(historyProvider.notifier).setContent(entry.id, content);
    if (ref.mounted) state = AsyncData(entry.withContent(content));
  }
}
