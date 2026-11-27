import 'dart:isolate';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Résultat d'une analyse.
sealed class AnalysisOutcome {
  const new();

  /// Niveau de synthèse.
  RiskLevel get level;

  /// Moment de l'analyse, en UTC.
  DateTime get analyzedAt;
}

/// Résultat de l'analyse d'un lien.
final class LinkOutcome extends AnalysisOutcome {
  /// Crée un résultat.
  const new(this.result);

  /// Analyse du lien.
  final UrlAnalysisResult result;

  @override
  RiskLevel get level => result.level;

  @override
  DateTime get analyzedAt => result.analyzedAt;
}

/// Résultat de l'analyse d'un message et de ses liens.
final class MessageOutcome extends AnalysisOutcome {
  /// Crée un résultat.
  const new(this.result);

  /// Analyse combinée.
  final CombinedResult result;

  @override
  RiskLevel get level => result.level;

  @override
  DateTime get analyzedAt => result.analyzedAt;
}

/// Analyse un lien ou un message, entièrement sur le téléphone.
abstract interface class AnalysisService {
  /// Analyse [request].
  Future<AnalysisOutcome> analyze(AnalysisRequest request);
}

/// Analyse locale, hors du fil d'affichage pour que l'écran reste fluide
/// même avec un message de 10 000 caractères.
final class LocalAnalysisService implements AnalysisService {
  /// Crée le service.
  const new();

  @override
  Future<AnalysisOutcome> analyze(AnalysisRequest request) {
    final kind = request.kind;
    final text = request.text;
    return Isolate.run(() => analyzeNow(kind, text));
  }

  /// Analyse immédiate, dans le fil courant.
  static AnalysisOutcome analyzeNow(AnalysisKind kind, String text) {
    const context = AnalysisContext();
    return switch (kind) {
      AnalysisKind.link => LinkOutcome(UrlAnalyzer().analyze(text, context)),
      AnalysisKind.message => MessageOutcome(
        CombinedAnalyzer().analyze(text, context),
      ),
    };
  }
}

/// Service d'analyse ; remplacé dans les tests.
final Provider<AnalysisService> analysisServiceProvider = Provider(
  (ref) => const LocalAnalysisService(),
);

/// Analyse d'une demande. Aucune nouvelle tentative automatique : en cas
/// d'erreur, l'écran l'affiche et propose « Réessayer ».
// Le type de famille n'est pas exporté par Riverpod.
// ignore: specify_nonobvious_property_types
final analysisProvider = FutureProvider.autoDispose
    .family<AnalysisOutcome, AnalysisRequest>(
      (ref, request) => ref.watch(analysisServiceProvider).analyze(request),
      retry: (_, _) => null,
    );
