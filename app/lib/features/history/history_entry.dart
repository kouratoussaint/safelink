import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Indice enregistré : code, gravité et explication, jamais l'extrait.
@immutable
final class StoredSignal {
  /// Crée un indice enregistré.
  const new(this.code, this.severity, this.reason);

  /// Indice relu depuis le stockage.
  factory fromJson(Map<String, Object?> json) => StoredSignal(
    json['code']! as String,
    Severity.values.byName(json['severity']! as String),
    json['reason']! as String,
  );

  /// Indice d'une analyse, sans son extrait.
  factory of(RiskSignal signal) =>
      StoredSignal(signal.code, signal.severity, signal.reason);

  /// Code stable de l'indice.
  final String code;

  /// Gravité.
  final Severity severity;

  /// Explication en français.
  final String reason;

  /// Forme JSON de l'indice.
  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      other is StoredSignal &&
      other.code == code &&
      other.severity == severity &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(code, severity, reason);
}

/// Lien repéré dans un message : domaine et verdict.
@immutable
final class StoredLink {
  /// Crée un lien enregistré.
  const new(this.domain, this.verdict);

  /// Lien relu depuis le stockage.
  factory fromJson(Map<String, Object?> json) => StoredLink(
    json['domain'] as String?,
    urlVerdictOf(json['verdict']! as String),
  );

  /// Domaine enregistré, ou `null` si l'adresse n'était pas analysable.
  final String? domain;

  /// Verdict du lien.
  final UrlVerdict verdict;

  /// Forme JSON du lien.
  Map<String, Object?> toJson() => {'domain': domain, 'verdict': verdict.code};

  @override
  bool operator ==(Object other) =>
      other is StoredLink && other.domain == domain && other.verdict == verdict;

  @override
  int get hashCode => Object.hash(domain, verdict);
}

/// Verdict de lien correspondant à [code].
UrlVerdict urlVerdictOf(String code) =>
    UrlVerdict.values.firstWhere((verdict) => verdict.code == code);

/// Verdict de message correspondant à [code].
MessageVerdict messageVerdictOf(String code) =>
    MessageVerdict.values.firstWhere((verdict) => verdict.code == code);

/// Partie chiffrée d'une vérification : domaine, liens et raisons.
@immutable
final class HistoryDetails {
  /// Crée le détail.
  const new({required this.domain, required this.links, required this.signals});

  /// Détail relu depuis le stockage.
  factory decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    return HistoryDetails(
      domain: json['domain'] as String?,
      links: [
        for (final link
            in (json['links']! as List).cast<Map<String, Object?>>())
          StoredLink.fromJson(link),
      ],
      signals: [
        for (final signal
            in (json['signals']! as List).cast<Map<String, Object?>>())
          StoredSignal.fromJson(signal),
      ],
    );
  }

  /// Domaine enregistré du lien analysé (vérification d'un lien).
  final String? domain;

  /// Liens repérés (vérification d'un message).
  final List<StoredLink> links;

  /// Indices relevés, sans extraits.
  final List<StoredSignal> signals;

  /// Tous les domaines cités, pour la recherche.
  Iterable<String> get domains => [
    ?domain,
    for (final link in links) ?link.domain,
  ];

  /// Forme JSON du détail.
  String encode() => jsonEncode({
    'domain': domain,
    'links': [for (final link in links) link.toJson()],
    'signals': [for (final signal in signals) signal.toJson()],
  });

  @override
  bool operator ==(Object other) =>
      other is HistoryDetails &&
      other.domain == domain &&
      listEquals(other.links, links) &&
      listEquals(other.signals, signals);

  @override
  int get hashCode =>
      Object.hash(domain, Object.hashAll(links), Object.hashAll(signals));
}

/// Vérification enregistrée.
///
/// En clair : nature, niveau, verdict, date, version des règles et codes des
/// indices. Chiffrés : le [details] (domaine, liens, raisons) et, seulement
/// sur demande explicite, le contenu complet [content] (lien ou texte).
@immutable
final class HistoryEntry {
  /// Crée une vérification.
  const new({
    required this.id,
    required this.kind,
    required this.level,
    required this.verdictCode,
    required this.analyzedAt,
    required this.rulesVersion,
    required this.signalCodes,
    required this.details,
    this.content,
  });

  /// Vérification minimale tirée d'un résultat, sans contenu complet.
  factory fromOutcome(String id, AnalysisOutcome outcome) {
    switch (outcome) {
      case LinkOutcome(:final result):
        final technical = result.technicalDetails;
        return HistoryEntry(
          id: id,
          kind: AnalysisKind.link,
          level: outcome.level,
          verdictCode: result.verdict.code,
          analyzedAt: result.analyzedAt,
          rulesVersion: result.rulesVersion,
          signalCodes: [for (final s in result.signals) s.code],
          details: HistoryDetails(
            domain: technical?.registrableDomain ?? technical?.host,
            links: const [],
            signals: [for (final s in result.signals) StoredSignal.of(s)],
          ),
        );
      case MessageOutcome(:final result):
        final message = result.message;
        return HistoryEntry(
          id: id,
          kind: AnalysisKind.message,
          level: outcome.level,
          verdictCode: message.verdict.code,
          analyzedAt: result.analyzedAt,
          rulesVersion: message.rulesVersion,
          signalCodes: [for (final s in message.signals) s.code],
          details: HistoryDetails(
            domain: null,
            links: [
              for (final link in result.links)
                StoredLink(
                  link.result.technicalDetails?.registrableDomain ??
                      link.result.technicalDetails?.host,
                  link.result.verdict,
                ),
            ],
            signals: [for (final s in message.signals) StoredSignal.of(s)],
          ),
        );
    }
  }

  /// Identifiant aléatoire.
  final String id;

  /// Lien ou message.
  final AnalysisKind kind;

  /// Niveau de synthèse (le plus sévère pour un message et ses liens).
  final RiskLevel level;

  /// Code du verdict du lien ou du texte du message.
  final String verdictCode;

  /// Moment de l'analyse, en UTC.
  final DateTime analyzedAt;

  /// Version des règles appliquées.
  final String rulesVersion;

  /// Codes des indices relevés.
  final List<String> signalCodes;

  /// Détail déchiffré ; `null` s'il ne peut plus être déchiffré.
  final HistoryDetails? details;

  /// Lien complet ou texte du message, conservé seulement sur demande.
  final String? content;

  /// Vrai si le détail ne peut plus être déchiffré.
  bool get isUnreadable => details == null;

  /// Copie avec un autre contenu complet.
  HistoryEntry withContent(String? content) => HistoryEntry(
    id: id,
    kind: kind,
    level: level,
    verdictCode: verdictCode,
    analyzedAt: analyzedAt,
    rulesVersion: rulesVersion,
    signalCodes: signalCodes,
    details: details,
    content: content,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.id == id &&
      other.kind == kind &&
      other.level == level &&
      other.verdictCode == verdictCode &&
      other.analyzedAt == analyzedAt &&
      other.rulesVersion == rulesVersion &&
      listEquals(other.signalCodes, signalCodes) &&
      other.details == details &&
      other.content == content;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    level,
    verdictCode,
    analyzedAt,
    rulesVersion,
    Object.hashAll(signalCodes),
    details,
    content,
  );

  /// Ni domaine ni contenu : ils peuvent être privés.
  @override
  String toString() => 'HistoryEntry($id, ${kind.name}, $verdictCode)';
}
