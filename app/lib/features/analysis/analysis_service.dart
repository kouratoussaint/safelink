import 'dart:isolate';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Ce que l'utilisateur veut vérifier.
enum AnalysisKind {
  /// Un lien.
  link,

  /// Le texte d'un message et ses liens.
  message,
}

/// Demande d'analyse : un texte et sa nature.
///
/// Deux demandes ne sont égales que si elles ont le même [id] : analyser
/// deux fois le même texte relance l'analyse.
@immutable
final class AnalysisRequest {
  /// Crée une demande.
  new(this.kind, this.text, {int? id})
    : id = id ?? DateTime.now().microsecondsSinceEpoch;

  /// Nature du contenu.
  final AnalysisKind kind;

  /// Texte saisi ou collé.
  final String text;

  /// Identifiant de la demande.
  final int id;

  @override
  bool operator ==(Object other) => other is AnalysisRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Le texte n'est jamais affiché : il peut contenir des données privées.
  @override
  String toString() => 'AnalysisRequest(${kind.name}, $id)';
}

/// État de la vérification en ligne d'une analyse.
enum OnlineStatus {
  /// Non demandée (désactivée ou pas encore choisie).
  notRequested,

  /// Rien à vérifier : adresse IP, nom sans extension connue, ou message
  /// sans lien.
  notApplicable,

  /// Faite : au moins une source a répondu.
  done,

  /// Tentée, mais aucune source n'a répondu (pas de connexion ?).
  unreachable,
}

/// Étape en cours d'une analyse.
enum AnalysisStage {
  /// Analyse sur le téléphone.
  local,

  /// Consultation des sources en ligne.
  online,
}

/// Résultat d'une analyse.
sealed class AnalysisOutcome {
  const new({this.online = OnlineStatus.notRequested});

  /// Niveau de synthèse.
  RiskLevel get level;

  /// Moment de l'analyse, en UTC.
  DateTime get analyzedAt;

  /// État de la vérification en ligne.
  final OnlineStatus online;

  /// Copie avec un autre état de vérification en ligne.
  AnalysisOutcome withOnline(OnlineStatus online);
}

/// Résultat de l'analyse d'un lien.
final class LinkOutcome extends AnalysisOutcome {
  /// Crée un résultat.
  const new(this.result, {super.online});

  /// Analyse du lien.
  final UrlAnalysisResult result;

  @override
  RiskLevel get level => result.level;

  @override
  DateTime get analyzedAt => result.analyzedAt;

  @override
  LinkOutcome withOnline(OnlineStatus online) =>
      LinkOutcome(result, online: online);
}

/// Résultat de l'analyse d'un message et de ses liens.
final class MessageOutcome extends AnalysisOutcome {
  /// Crée un résultat.
  const new(this.result, {super.online});

  /// Analyse combinée.
  final CombinedResult result;

  @override
  RiskLevel get level => result.level;

  @override
  DateTime get analyzedAt => result.analyzedAt;

  @override
  MessageOutcome withOnline(OnlineStatus online) =>
      MessageOutcome(result, online: online);
}

/// Analyse un lien ou un message.
abstract interface class AnalysisService {
  /// Analyse [request] ; avec [online], consulte aussi les sources en
  /// ligne. [onStage] est appelé à chaque changement d'étape, jamais avant
  /// la première attente.
  Future<AnalysisOutcome> analyze(
    AnalysisRequest request, {
    bool online = false,
    void Function(AnalysisStage stage)? onStage,
  });
}

/// Analyse sur le téléphone, complétée si demandé par une vérification en
/// ligne du seul nom des sites.
///
/// Les analyses tournent hors du fil d'affichage ([useIsolates]) pour que
/// l'écran reste fluide même avec un message de 10 000 caractères.
final class DeviceAnalysisService implements AnalysisService {
  /// Crée le service.
  new({OnlineChecker? checker, this.useIsolates = true})
    : checker = checker ?? OnlineChecker();

  /// Vérificateur en ligne.
  final OnlineChecker checker;

  /// Faux dans les tests de l'interface, qui n'ont pas de vrais isolats.
  final bool useIsolates;

  Future<T> _run<T>(T Function() computation) =>
      useIsolates ? Isolate.run(computation) : Future.value(computation());

  @override
  Future<AnalysisOutcome> analyze(
    AnalysisRequest request, {
    bool online = false,
    void Function(AnalysisStage stage)? onStage,
  }) async {
    final kind = request.kind;
    final text = request.text;
    // L'étape « local » est l'étape initiale : rien à signaler ici, d'autant
    // que ce code s'exécute pendant la construction du fournisseur.
    final local = await _run(() => analyzeNow(kind, text));
    if (!online) return local;
    final targets = onlineTargets(local);
    if (targets.isEmpty) return local.withOnline(OnlineStatus.notApplicable);

    onStage?.call(AnalysisStage.online);
    final answers = await Future.wait(targets.map(checker.check));
    final evidence = {
      for (final (i, target) in targets.indexed) target: answers[i],
    };
    final answered = answers.any(
      (e) =>
          e.reputation.any((r) => r.status != ProviderStatus.unavailable) ||
          e.resolution?.status != LookupStatus.unavailable ||
          e.registration?.status != LookupStatus.unavailable,
    );
    if (!answered) return local.withOnline(OnlineStatus.unreachable);
    final outcome = await _run(
      () => analyzeNow(kind, text, evidence: evidence),
    );
    return outcome.withOnline(OnlineStatus.done);
  }

  /// Analyse immédiate, dans le fil courant, avec les éléments recueillis
  /// en ligne pour chaque nom de site ([evidence]).
  static AnalysisOutcome analyzeNow(
    AnalysisKind kind,
    String text, {
    Map<OnlineLookupTarget, OnlineEvidence> evidence = const {},
  }) {
    const context = AnalysisContext();
    final parser = UrlParser();
    OnlineEvidence evidenceFor(String url) {
      final parsed = parser.parse(url);
      if (parsed is! ParsedUrl) return OnlineEvidence.none;
      final target = OnlineLookupTarget.of(parsed);
      return target == null
          ? OnlineEvidence.none
          : evidence[target] ?? OnlineEvidence.none;
    }

    return switch (kind) {
      AnalysisKind.link => LinkOutcome(
        UrlAnalyzer().analyzeOnline(text, context, evidenceFor(text)),
      ),
      AnalysisKind.message => MessageOutcome(
        CombinedAnalyzer().analyze(
          text,
          context,
          online: (link) => evidenceFor(link.url),
        ),
      ),
    };
  }

  /// Noms de sites à vérifier en ligne pour un résultat local, sans
  /// doublon.
  static List<OnlineLookupTarget> onlineTargets(AnalysisOutcome outcome) {
    final urls = switch (outcome) {
      LinkOutcome(:final result) => [?result.url],
      MessageOutcome(:final result) => [
        for (final link in result.links) ?link.result.url,
      ],
    };
    return {for (final url in urls) ?OnlineLookupTarget.of(url)}.toList();
  }
}

/// Service d'analyse ; remplacé dans les tests.
final Provider<AnalysisService> analysisServiceProvider = Provider(
  (ref) => DeviceAnalysisService(checker: ref.watch(onlineCheckerProvider)),
);

/// Étape en cours de l'analyse d'une demande.
// Le type de famille n'est pas exporté par Riverpod.
// ignore: specify_nonobvious_property_types
final analysisStageProvider = NotifierProvider.autoDispose
    .family<AnalysisStageController, AnalysisStage, AnalysisRequest>(
      AnalysisStageController.new,
    );

/// Retient l'étape en cours.
class AnalysisStageController extends Notifier<AnalysisStage> {
  /// Crée le contrôleur pour [request].
  new(this.request);

  /// Demande analysée.
  final AnalysisRequest request;

  @override
  AnalysisStage build() => AnalysisStage.local;

  /// Passe à l'étape [stage].
  void set(AnalysisStage stage) {
    if (ref.mounted) state = stage;
  }
}

/// Analyse d'une demande. Aucune nouvelle tentative automatique : en cas
/// d'erreur, l'écran l'affiche et propose « Réessayer ». Activer la
/// vérification en ligne relance l'analyse.
// Le type de famille n'est pas exporté par Riverpod.
// ignore: specify_nonobvious_property_types
final analysisProvider = FutureProvider.autoDispose
    .family<AnalysisOutcome, AnalysisRequest>((ref, request) {
      final online = ref.watch(onlineChoiceProvider) == OnlineChoice.enabled;
      final stage = ref.read(analysisStageProvider(request).notifier);
      return ref
          .watch(analysisServiceProvider)
          .analyze(request, online: online, onStage: stage.set);
    }, retry: (_, _) => null);
