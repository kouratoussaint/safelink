import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/codes.dart';
import 'package:safelink_engine/src/common/content_type.dart';
import 'package:safelink_engine/src/common/notes.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/common/verdicts.dart';

/// Lieu où l'analyse a été réalisée (`local_or_network` du cahier des
/// charges).
enum Processing {
  /// Analyse entièrement réalisée sur l'appareil.
  localOnly,

  /// Analyse locale complétée par une consultation réseau.
  localAndNetwork,
}

/// Effet de l'analyse sur la confidentialité, affiché à l'utilisateur.
enum PrivacyImpact {
  /// Rien n'a quitté l'appareil.
  stayedOnDevice,

  /// L'appareil a contacté une source (par exemple pour télécharger une
  /// liste) sans lui transmettre le contenu analysé.
  providerContactedWithoutContent,

  /// Le contenu analysé, ou une partie, a été transmis à une source après
  /// consentement explicite.
  contentSentToProvider,
}

/// Fonction renvoyant l'heure courante ; injectable pour des tests
/// déterministes.
typedef Clock = DateTime Function();

/// Contexte fourni à chaque analyse.
@immutable
final class AnalysisContext {
  /// Crée un contexte. Par défaut, l'horloge est l'heure système et la
  /// langue est le français.
  const new({this._clock, this.languageCode = 'fr'});

  final Clock? _clock;

  /// Code de langue des explications produites (`fr` au MVP).
  final String languageCode;

  /// Heure courante, toujours en UTC.
  DateTime now() => (_clock ?? DateTime.now)().toUtc();
}

/// Résultat commun à toutes les analyses, quel que soit le type de contenu.
///
/// Les analyseurs de liens et de messages en dérivent leurs propres
/// résultats, avec leurs verdicts spécifiques. Les listes exposées sont non
/// modifiables.
@immutable
abstract base class AnalysisResult {
  /// Initialise les champs communs. Lève une [ArgumentError] si la date
  /// n'est pas en UTC, si la version des règles est vide ou si aucune
  /// limite n'est fournie : chaque verdict doit afficher au moins une
  /// limite ou incertitude.
  new({
    required this.contentType,
    required List<RiskSignal> signals,
    required List<Limitation> limitations,
    required List<RecommendedAction> recommendedActions,
    required DateTime analyzedAt,
    required String rulesVersion,
    required this.processing,
    required this.privacyImpact,
  }) : signals = List.unmodifiable(signals),
       limitations = List.unmodifiable(limitations),
       recommendedActions = List.unmodifiable(recommendedActions),
       analyzedAt = checkUtc(analyzedAt, 'analyzedAt'),
       rulesVersion = checkNotBlank(rulesVersion, 'rulesVersion') {
    if (this.limitations.isEmpty) {
      throw ArgumentError.value(
        limitations,
        'limitations',
        'Au moins une limite doit accompagner chaque résultat.',
      );
    }
  }

  /// Type de contenu analysé.
  final ContentType contentType;

  /// Indices relevés, dans l'ordre de détection.
  final List<RiskSignal> signals;

  /// Ce qui n'a pas été vérifié ou ne peut pas l'être.
  final List<Limitation> limitations;

  /// Gestes recommandés.
  final List<RecommendedAction> recommendedActions;

  /// Moment de l'analyse, en UTC.
  final DateTime analyzedAt;

  /// Version des règles utilisées.
  final String rulesVersion;

  /// Lieu de l'analyse.
  final Processing processing;

  /// Effet de l'analyse sur la confidentialité.
  final PrivacyImpact privacyImpact;

  /// Niveau de synthèse du résultat.
  RiskLevel get level;
}

/// Analyseur d'un type de contenu.
///
/// Un analyseur est pur : il n'effectue aucune entrée-sortie et renvoie
/// toujours le même résultat pour la même entrée et la même heure.
abstract interface class ContentAnalyzer<I, R extends AnalysisResult> {
  /// Type de contenu traité par cet analyseur.
  ContentType get contentType;

  /// Analyse [input] dans le [context] donné.
  R analyze(I input, AnalysisContext context);
}
