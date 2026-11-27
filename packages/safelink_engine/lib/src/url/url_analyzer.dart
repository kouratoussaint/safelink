import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/analysis.dart';
import 'package:safelink_engine/src/common/content_type.dart';
import 'package:safelink_engine/src/common/notes.dart';
import 'package:safelink_engine/src/common/provider_result.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/common/verdicts.dart';
import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/idna.dart';
import 'package:safelink_engine/src/url/online_evidence.dart';
import 'package:safelink_engine/src/url/online_rules.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/psl_data.g.dart';
import 'package:safelink_engine/src/url/unicode_security.dart';
import 'package:safelink_engine/src/url/url_masking.dart';
import 'package:safelink_engine/src/url/url_parser.dart';
import 'package:safelink_engine/src/url/url_rules.dart';

/// Détails techniques d'un lien analysé, montrés à la demande.
@immutable
final class UrlTechnicalDetails {
  /// Crée les détails ; utilisé par [UrlAnalyzer].
  new({
    required this.displayUrl,
    required this.maskedValues,
    required this.scheme,
    required this.host,
    required this.hostUnicode,
    required this.hostType,
    required this.port,
    required this.registrableDomain,
    required this.publicSuffix,
    required this.isPrivateSuffix,
    required Iterable<String> scripts,
    required Iterable<UrlNormalization> normalizations,
    required Iterable<BrandMatch> brandMatches,
  }) : scripts = Set.unmodifiable(scripts),
       normalizations = List.unmodifiable(normalizations),
       brandMatches = List.unmodifiable(brandMatches);

  /// Lien normalisé, données sensibles masquées, hôte en forme technique.
  final String displayUrl;

  /// Nombre de valeurs masquées dans [displayUrl].
  final int maskedValues;

  /// `http` ou `https`.
  final String scheme;

  /// Hôte en ASCII (Punycode pour les noms internationaux).
  final String host;

  /// Hôte lisible.
  final String hostUnicode;

  /// Nature de l'hôte.
  final UrlHostType hostType;

  /// Port explicite, s'il diffère de celui du protocole.
  final int? port;

  /// Domaine réellement enregistré.
  final String? registrableDomain;

  /// Suffixe public (`bf`, `co.uk`, `blogspot.com`).
  final String? publicSuffix;

  /// Vrai si le suffixe est une plateforme ouverte à tous.
  final bool isPrivateSuffix;

  /// Alphabets du nom de domaine.
  final Set<String> scripts;

  /// Transformations appliquées au lien, à montrer à l'utilisateur.
  final List<UrlNormalization> normalizations;

  /// Rapprochements avec les marques de référence.
  final List<BrandMatch> brandMatches;
}

/// Résultat de l'analyse d'un lien.
final class UrlAnalysisResult extends AnalysisResult {
  /// Crée un résultat ; utilisé par [UrlAnalyzer].
  new({
    required this.verdict,
    required this.confidence,
    required super.signals,
    required super.limitations,
    required super.recommendedActions,
    required super.analyzedAt,
    required super.rulesVersion,
    required List<ProviderResult> providerResults,
    this.url,
    this.failure,
    this.technicalDetails,
    this.registration,
    this.resolution,
  }) : providerResults = List.unmodifiable(providerResults),
       super(
         contentType: ContentType.url,
         processing:
             providerResults.isEmpty &&
                 registration == null &&
                 resolution == null
             ? Processing.localOnly
             : Processing.localAndNetwork,
         privacyImpact:
             providerResults.isEmpty &&
                 registration == null &&
                 resolution == null
             ? PrivacyImpact.stayedOnDevice
             : PrivacyImpact.providerContactedWithoutContent,
       ) {
    if ((url == null) == (failure == null)) {
      throw ArgumentError(
        'Un résultat porte un lien lu ou un échec, pas les '
        'deux.',
      );
    }
  }

  /// Verdict normatif.
  final UrlVerdict verdict;

  /// Confiance dans le verdict.
  final Confidence confidence;

  /// Lien lu, si la lecture a réussi.
  final ParsedUrl? url;

  /// Motif du refus, si le texte n'est pas un lien analysable.
  final UrlParseFailure? failure;

  /// Résultats des sources de réputation consultées en ligne.
  final List<ProviderResult> providerResults;

  /// Date d'enregistrement du domaine, si elle a été consultée.
  final DomainRegistration? registration;

  /// Existence du nom dans le DNS, si elle a été vérifiée.
  final DomainResolution? resolution;

  /// Détails techniques, si la lecture a réussi.
  final UrlTechnicalDetails? technicalDetails;

  @override
  RiskLevel get level => verdict.level;
}

/// Règles de décision du verdict d'un lien.
///
/// - `KNOWN_THREAT` : seulement si une source de réputation récente signale
///   le lien. Aucune règle locale ne peut le produire.
/// - `SUSPICIOUS` : au moins un indice fort, ou au moins deux indices moyens,
///   ou une correspondance dans une liste périmée.
/// - `NO_KNOWN_THREAT` : seulement si une source récente a été consultée
///   sans correspondance, sans aucun indice moyen ou fort, et si rien ne
///   cache la page réelle ([reassuranceBlockers]).
/// - `INCONCLUSIVE` : dans tous les autres cas, notamment sans source de
///   réputation.
final class UrlVerdictPolicy {
  /// Crée la politique ; [maxFeedAge] est l'âge maximal d'une liste.
  const new({this.maxFeedAge = const Duration(days: 7)});

  /// Âge maximal d'une liste de réputation pour qu'elle compte.
  final Duration maxFeedAge;

  /// Indices qui empêchent « Aucun danger connu détecté » : la réputation
  /// du nom ne dit rien de la page réelle (lien raccourci, redirection,
  /// page publiée sur un service de partage) ou le site n'existe pas.
  static const Set<String> reassuranceBlockers = {
    UrlSignalCodes.shortener,
    UrlSignalCodes.redirectParameter,
    UrlSignalCodes.userContent,
    UrlSignalCodes.domainNotFound,
  };

  /// Verdict et confiance pour ces indices et ces résultats de sources.
  (UrlVerdict, Confidence) decide(
    List<RiskSignal> signals,
    List<ProviderResult> providerResults,
  ) {
    final freshMatch = providerResults.any(
      (r) => r.status == ProviderStatus.match && r.isFreshWithin(maxFeedAge),
    );
    if (freshMatch) return (UrlVerdict.knownThreat, Confidence.high);

    final staleMatch = providerResults.any(
      (r) => r.status == ProviderStatus.match,
    );
    final high = signals.where((s) => s.severity == Severity.high).toList();
    final medium = signals.where((s) => s.severity == Severity.medium).length;
    if (staleMatch || high.isNotEmpty || medium >= 2) {
      final confident =
          staleMatch || high.any((s) => s.confidence == Confidence.high);
      return (
        UrlVerdict.suspicious,
        confident ? Confidence.high : Confidence.medium,
      );
    }

    final freshNoMatch = providerResults.any(
      (r) => r.status == ProviderStatus.noMatch && r.isFreshWithin(maxFeedAge),
    );
    final reassuring =
        freshNoMatch &&
        medium == 0 &&
        !signals.any((s) => reassuranceBlockers.contains(s.code));
    if (reassuring) return (UrlVerdict.noKnownThreat, Confidence.medium);
    return (UrlVerdict.inconclusive, Confidence.low);
  }
}

/// Analyse d'un lien : lecture, indices heuristiques, éléments recueillis en
/// ligne par l'application s'il y en a, verdict prudent.
///
/// N'ouvre jamais le lien et n'effectue aucune entrée-sortie : les
/// consultations en ligne sont faites par l'application, qui en transmet
/// les réponses ([OnlineEvidence]).
final class UrlAnalyzer implements ContentAnalyzer<String, UrlAnalysisResult> {
  /// Crée un analyseur.
  new({
    UrlParser? parser,
    UrlRules? rules,
    this.policy = const UrlVerdictPolicy(),
  }) : parser = parser ?? UrlParser(),
       rules = rules ?? UrlRules();

  /// Version des règles d'analyse des liens.
  static const rulesVersion = 'url-1.2.0';

  /// Lecteur de liens.
  final UrlParser parser;

  /// Règles heuristiques.
  final UrlRules rules;

  /// Règles de décision du verdict.
  final UrlVerdictPolicy policy;

  @override
  ContentType get contentType => ContentType.url;

  /// Version complète : règles et données embarquées.
  String get fullRulesVersion =>
      '$rulesVersion+psl.$pslRetrievedOn+unicode.${UnicodeScripts.version}'
      '+marques.${rules.brandMatcher.registry.brands.length}';

  @override
  UrlAnalysisResult analyze(String input, AnalysisContext context) =>
      analyzeOnline(input, context, OnlineEvidence.none);

  /// Analyse [input] en tenant compte des résultats de sources de
  /// réputation déjà obtenus ([providerResults]).
  UrlAnalysisResult analyzeWithReputation(
    String input,
    AnalysisContext context,
    List<ProviderResult> providerResults,
  ) => analyzeOnline(
    input,
    context,
    OnlineEvidence(reputation: providerResults),
  );

  /// Analyse [input] avec les éléments recueillis en ligne par
  /// l'application ([evidence]) : réputation, date d'enregistrement du
  /// domaine, existence du nom.
  UrlAnalysisResult analyzeOnline(
    String input,
    AnalysisContext context,
    OnlineEvidence evidence,
  ) {
    final now = context.now();
    final providerResults = evidence.reputation;
    final parsed = parser.parse(input);
    switch (parsed) {
      case UrlParseFailure():
        return UrlAnalysisResult(
          verdict: UrlVerdict.invalid,
          confidence: Confidence.high,
          failure: parsed,
          signals: const [],
          limitations: [
            Limitation(
              code: 'URL_NOT_ANALYZED',
              description: parsed.error.description,
            ),
          ],
          recommendedActions: _actionsFor(UrlVerdict.invalid, parsed),
          analyzedAt: now,
          rulesVersion: fullRulesVersion,
          providerResults: providerResults,
        );
      case ParsedUrl():
        final (local, brandMatches) = rules.evaluate(parsed, now);
        final isOfficial = brandMatches.any(
          (m) => m.kind == BrandMatchKind.official,
        );
        final online = OnlineRules(maxFeedAge: policy.maxFeedAge)
            .evaluate(parsed, evidence, now, isOfficial: isOfficial);
        final signals = _bySeverity([...online, ...local]);
        final (verdict, confidence) = policy.decide(signals, providerResults);
        return UrlAnalysisResult(
          verdict: verdict,
          confidence: confidence,
          url: parsed,
          signals: signals,
          limitations: _limitations(parsed, providerResults),
          recommendedActions: _actionsFor(verdict, null),
          analyzedAt: now,
          rulesVersion: fullRulesVersion,
          providerResults: providerResults,
          technicalDetails: _details(parsed, brandMatches),
          registration: evidence.registration,
          resolution: evidence.resolution,
        );
    }
  }

  /// Tri stable du plus grave au moins grave.
  static List<RiskSignal> _bySeverity(List<RiskSignal> signals) {
    final ordered = [for (final (i, signal) in signals.indexed) (i, signal)]
      ..sort((a, b) {
        final bySeverity = b.$2.severity.index.compareTo(a.$2.severity.index);
        return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
      });
    return [for (final (_, signal) in ordered) signal];
  }

  UrlTechnicalDetails _details(ParsedUrl url, List<BrandMatch> matches) {
    final suffix = url.publicSuffix;
    final label = switch ((url.registrableDomain, suffix)) {
      (final registrable?, final suffix?) => registrable.substring(
        0,
        registrable.length - suffix.publicSuffix.length - 1,
      ),
      _ => url.hostType == UrlHostType.domain ? url.host : '',
    };
    return UrlTechnicalDetails(
      displayUrl: UrlMasking.maskedHref(url),
      maskedValues: UrlMasking.maskedCount(url),
      scheme: url.scheme,
      host: url.host,
      hostUnicode: url.hostUnicode,
      hostType: url.hostType,
      port: url.port,
      registrableDomain: url.registrableDomain,
      publicSuffix: suffix?.publicSuffix,
      isPrivateSuffix: suffix?.isPrivateSuffix ?? false,
      scripts: UnicodeScripts.scriptsOf(Idna.toUnicode(label)),
      normalizations: url.normalizations,
      brandMatches: matches,
    );
  }

  static List<Limitation> _limitations(
    ParsedUrl url,
    List<ProviderResult> providerResults,
  ) => [
    Limitation(
      code: 'PAGE_NOT_OPENED',
      description:
          'SafeLink n’ouvre pas le lien : le contenu de la page n’a pas été '
          'examiné.',
    ),
    if (!providerResults.any((r) => r.isConclusive))
      Limitation(
        code: 'REPUTATION_UNAVAILABLE',
        description:
            'Vérification de réputation non disponible : le lien n’a été '
            'comparé à aucune liste de sites signalés.',
      )
    else
      Limitation(
        code: 'REPUTATION_DOMAIN_LEVEL',
        description:
            'La vérification en ligne porte sur le nom du site, pas sur la '
            'page : une fausse page publiée sur un site légitime peut passer '
            'inaperçue, et un site très récent peut ne pas encore être '
            'signalé.',
      ),
    Limitation(
      code: 'LOCAL_RULES_LIMITS',
      description:
          'Les règles locales repèrent des procédés courants ; un site '
          'malveillant peut n’en présenter aucun.',
    ),
    if (url.normalizations.contains(UrlNormalization.schemeAdded))
      Limitation(
        code: 'URL_SCHEME_ASSUMED',
        description: UrlNormalization.schemeAdded.description,
      ),
  ];

  static List<RecommendedAction> _actionsFor(
    UrlVerdict verdict,
    UrlParseFailure? failure,
  ) {
    RecommendedAction action(String code, String description) =>
        RecommendedAction(code: code, description: description);
    final doNotOpen = action('DO_NOT_OPEN', 'N’ouvrez pas ce lien.');
    final neverShareCodes = action(
      'NEVER_SHARE_CODES',
      'Ne communiquez jamais un code reçu par SMS, un code secret ou un mot '
          'de passe, même à quelqu’un qui se présente comme un agent.',
    );
    final verifyOfficially = action(
      'VERIFY_OFFICIAL_CHANNEL',
      'En cas de doute, contactez l’organisme par son numéro ou son '
          'application officiels, jamais par les coordonnées du message.',
    );
    return switch (verdict) {
      UrlVerdict.knownThreat => [
        doNotOpen,
        action('DELETE_MESSAGE', 'Supprimez le message qui contenait ce lien.'),
        action(
          'IF_ALREADY_OPENED',
          'Si vous avez déjà saisi des informations, changez vos mots de '
              'passe et prévenez votre banque ou votre opérateur.',
        ),
      ],
      UrlVerdict.suspicious => [doNotOpen, neverShareCodes, verifyOfficially],
      UrlVerdict.inconclusive || UrlVerdict.noKnownThreat => [
        action(
          'OPEN_ONLY_IF_EXPECTED',
          'N’ouvrez le lien que si vous l’attendiez et connaissez '
              'l’expéditeur.',
        ),
        neverShareCodes,
        verifyOfficially,
      ],
      UrlVerdict.invalid => [
        if (failure?.error == UrlParseError.nonWebScheme) doNotOpen,
        verifyOfficially,
      ],
    };
  }
}
