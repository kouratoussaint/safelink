import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/analysis.dart';
import 'package:safelink_engine/src/common/content_type.dart';
import 'package:safelink_engine/src/common/notes.dart';
import 'package:safelink_engine/src/common/provider_result.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/common/verdicts.dart';
import 'package:safelink_engine/src/url/brands.dart';
import 'package:safelink_engine/src/url/idna.dart';
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
  }) : providerResults = List.unmodifiable(providerResults),
       super(
         contentType: ContentType.url,
         processing: Processing.localOnly,
         privacyImpact: PrivacyImpact.stayedOnDevice,
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

  /// Résultats des sources de réputation consultées (aucune au lot B).
  final List<ProviderResult> providerResults;

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
///   sans correspondance.
/// - `INCONCLUSIVE` : dans tous les autres cas, notamment sans source de
///   réputation.
final class UrlVerdictPolicy {
  /// Crée une politique. [maxFeedAge] est l'âge maximal d'une liste de
  /// réputation pour être jugée récente.
  const new({this.maxFeedAge = const Duration(days: 7)});

  /// Âge maximal d'une liste récente.
  final Duration maxFeedAge;

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
    if (freshNoMatch) return (UrlVerdict.noKnownThreat, Confidence.medium);
    return (UrlVerdict.inconclusive, Confidence.low);
  }
}

/// Analyse locale d'un lien : lecture, indices heuristiques, verdict prudent.
///
/// N'ouvre jamais le lien et n'effectue aucune entrée-sortie.
final class UrlAnalyzer implements ContentAnalyzer<String, UrlAnalysisResult> {
  /// Crée un analyseur.
  new({
    UrlParser? parser,
    UrlRules? rules,
    this.policy = const UrlVerdictPolicy(),
  }) : parser = parser ?? UrlParser(),
       rules = rules ?? UrlRules();

  /// Version des règles d'analyse des liens.
  static const rulesVersion = 'url-1.0.0';

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
      analyzeWithReputation(input, context, const []);

  /// Analyse [input] en tenant compte des résultats de sources de
  /// réputation déjà obtenus ([providerResults]).
  UrlAnalysisResult analyzeWithReputation(
    String input,
    AnalysisContext context,
    List<ProviderResult> providerResults,
  ) {
    final now = context.now();
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
        final (signals, brandMatches) = rules.evaluate(parsed, now);
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
        );
    }
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
