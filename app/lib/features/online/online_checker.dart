import 'dart:async';

import 'package:safelink/features/online/dns_message.dart';
import 'package:safelink/features/online/rdap_bootstrap.g.dart';
import 'package:safelink/features/online/safe_browsing.dart';
import 'package:safelink/features/online/transports.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Source de réputation consultée en ligne.
enum ReputationSource {
  /// Quad9, résolveur public à but non lucratif (Suisse).
  quad9('QUAD9', 'Quad9', 'https://dns.quad9.net/dns-query'),

  /// Cloudflare 1.1.1.1 for Families, filtre des logiciels malveillants.
  cloudflare(
    'CLOUDFLARE_SECURITY',
    'Cloudflare',
    'https://security.cloudflare-dns.com/dns-query',
  );

  new(this.providerId, this.label, this.endpoint);

  /// Identifiant stable, porté par les résultats.
  final String providerId;

  /// Nom affiché.
  final String label;

  /// Adresse DNS sur HTTPS du résolveur filtrant.
  final String endpoint;

  /// Source correspondant à [providerId], si elle existe.
  static ReputationSource? byProviderId(String providerId) {
    for (final source in values) {
      if (source.providerId == providerId) return source;
    }
    return null;
  }
}

/// Résolveur sans filtrage, pour savoir si un nom existe.
const unfilteredResolver = 'https://cloudflare-dns.com/dns-query';

/// Consulte en ligne ce qui peut éclairer l'analyse d'un lien, sans jamais
/// transmettre le lien complet :
/// - le nom du site (`www.exemple.com`) aux résolveurs filtrants Quad9 et
///   Cloudflare, qui le bloquent s'il figure dans leurs listes de menaces ;
/// - le même nom à un résolveur sans filtrage, pour savoir s'il existe ;
/// - le domaine enregistré (`exemple.com`) au serveur RDAP de son registre,
///   pour connaître sa date de création.
///
/// Toutes les requêtes sont chiffrées (HTTPS) et partent en parallèle.
/// Une source qui ne répond pas n'empêche jamais l'analyse : son résultat
/// est simplement « indisponible ».
final class OnlineChecker {
  /// Crée le vérificateur ; transports et horloge remplaçables en test.
  new({
    this.dns = const Http2DohTransport(),
    this.json = const IoJsonTransport(),
    this.safeBrowsing,
    DateTime Function()? clock,
    this.budget = const Duration(seconds: 10),
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  /// Google Safe Browsing, si une clé d'API est configurée.
  final SafeBrowsingClient? safeBrowsing;

  /// Transport DNS sur HTTPS.
  final DohTransport dns;

  /// Transport JSON pour RDAP.
  final JsonTransport json;

  final DateTime Function() _clock;

  /// Délai maximal de l'ensemble des consultations d'un lien.
  final Duration budget;

  /// Réponses déjà obtenues pendant la session, pour ne pas reposer la
  /// même question (gardées en mémoire seulement).
  final _cache = <OnlineLookupTarget, OnlineEvidence>{};

  /// Consulte les sources pour chaque lien de [urls] : une fois par nom de
  /// site pour le DNS et le registre, une fois par lien pour Google Safe
  /// Browsing (qui ne reçoit que des préfixes d'empreintes). Les éléments
  /// sont rangés par adresse normalisée (`ParsedUrl.href`).
  Future<Map<String, OnlineEvidence>> checkAll(List<ParsedUrl> urls) async {
    final targetOf = {
      for (final url in urls) url.href: OnlineLookupTarget.of(url),
    };
    final targets = targetOf.values.nonNulls.toSet().toList();
    final domainAnswers = await Future.wait(targets.map(check));
    final byTarget = {
      for (final (i, target) in targets.indexed) target: domainAnswers[i],
    };
    final browsing = safeBrowsing;
    final checkedAt = _clock();
    final googleAnswers = browsing == null
        ? null
        : await Future.wait([
            for (final url in urls) browsing.check(url, checkedAt),
          ]).timeout(
            budget,
            onTimeout: () => [
              for (final _ in urls)
                ProviderResult(
                  providerId: SafeBrowsingClient.providerId,
                  status: ProviderStatus.unavailable,
                  checkedAt: checkedAt,
                ),
            ],
          );
    return {
      for (final (i, url) in urls.indexed)
        url.href: _merge(byTarget[targetOf[url.href]], googleAnswers?[i]),
    };
  }

  static OnlineEvidence _merge(
    OnlineEvidence? domain,
    ProviderResult? google,
  ) => OnlineEvidence(
    reputation: [...?domain?.reputation, ?google],
    registration: domain?.registration,
    resolution: domain?.resolution,
  );

  /// Consulte le DNS et le registre pour [target].
  Future<OnlineEvidence> check(OnlineLookupTarget target) async {
    final cached = _cache[target];
    if (cached != null) return cached;
    final checkedAt = _clock();
    final query = DnsMessage.query(target.host);

    Future<DnsResponse?> resolve(String endpoint) async {
      try {
        return DnsMessage.parse(await dns.send(Uri.parse(endpoint), query));
      } on OnlineLookupException {
        return null;
      } on FormatException {
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      resolve(unfilteredResolver),
      for (final source in ReputationSource.values) resolve(source.endpoint),
      _registration(target.domain, checkedAt),
    ]).timeout(budget, onTimeout: () => List.filled(4, null));

    final unfiltered = results[0] as DnsResponse?;
    final resolution = DomainResolution(
      status: switch (unfiltered) {
        null => LookupStatus.unavailable,
        _ when unfiltered.isNameError => LookupStatus.notFound,
        _ when unfiltered.exists => LookupStatus.found,
        _ => LookupStatus.unavailable,
      },
      checkedAt: checkedAt,
    );
    final reputation = [
      for (final (i, source) in ReputationSource.values.indexed)
        _reputation(source, results[i + 1] as DnsResponse?, checkedAt),
    ];
    final evidence = OnlineEvidence(
      reputation: reputation,
      registration:
          results[3] as DomainRegistration? ??
          DomainRegistration.unavailable(checkedAt: checkedAt),
      resolution: resolution,
    );
    // Une réponse complète est gardée ; une réponse partielle sera
    // redemandée à la prochaine analyse.
    if (reputation.every((r) => r.isConclusive) &&
        resolution.status != LookupStatus.unavailable) {
      _cache[target] = evidence;
    }
    return evidence;
  }

  static ProviderResult _reputation(
    ReputationSource source,
    DnsResponse? response,
    DateTime checkedAt,
  ) {
    if (response == null) {
      return ProviderResult(
        providerId: source.providerId,
        status: ProviderStatus.unavailable,
        checkedAt: checkedAt,
      );
    }
    if (response.isBlocked) {
      return ProviderResult(
        providerId: source.providerId,
        status: ProviderStatus.match,
        checkedAt: checkedAt,
        // Service en temps réel : la liste est à jour à la consultation.
        feedUpdatedAt: checkedAt,
        matches: [ThreatMatch(threatType: ThreatType.other)],
      );
    }
    if (response.exists || response.isNameError) {
      return ProviderResult(
        providerId: source.providerId,
        status: ProviderStatus.noMatch,
        checkedAt: checkedAt,
        feedUpdatedAt: checkedAt,
      );
    }
    return ProviderResult(
      providerId: source.providerId,
      status: ProviderStatus.error,
      checkedAt: checkedAt,
      errorCode: 'DNS_RCODE_${response.responseCode}',
    );
  }

  /// Date de création de [domain] d'après le serveur RDAP de son registre.
  Future<DomainRegistration> _registration(
    String domain,
    DateTime checkedAt,
  ) async {
    final base = rdapServers[domain.substring(domain.lastIndexOf('.') + 1)];
    if (base == null) {
      return DomainRegistration.unavailable(checkedAt: checkedAt);
    }
    try {
      final document = await json.get(Uri.parse('${base}domain/$domain'));
      if (document == null) {
        return DomainRegistration.notFound(checkedAt: checkedAt);
      }
      final registeredAt = registrationDate(document);
      return registeredAt == null
          ? DomainRegistration.unavailable(checkedAt: checkedAt)
          : DomainRegistration.found(
              registeredAt: registeredAt,
              checkedAt: checkedAt,
            );
    } on OnlineLookupException {
      return DomainRegistration.unavailable(checkedAt: checkedAt);
    }
  }

  /// Date de l'évènement « registration » d'une réponse RDAP (RFC 9083).
  static DateTime? registrationDate(Map<String, Object?> document) {
    final events = document['events'];
    if (events is! List) return null;
    for (final event in events) {
      if (event is Map &&
          event['eventAction'] == 'registration' &&
          event['eventDate'] is String) {
        return DateTime.tryParse(event['eventDate']! as String)?.toUtc();
      }
    }
    return null;
  }
}
