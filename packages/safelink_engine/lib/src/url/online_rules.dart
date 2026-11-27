import 'package:safelink_engine/src/common/provider_result.dart';
import 'package:safelink_engine/src/common/signal.dart';
import 'package:safelink_engine/src/url/online_evidence.dart';
import 'package:safelink_engine/src/url/parsed_url.dart';
import 'package:safelink_engine/src/url/url_rules.dart';

/// Indices tirés des consultations en ligne faites par l'application :
/// réputation, date d'enregistrement du domaine, existence du nom.
final class OnlineRules {
  /// Crée les règles.
  const new({this.maxFeedAge = const Duration(days: 7)});

  /// Âge maximal d'une réponse de réputation pour qu'elle compte.
  final Duration maxFeedAge;

  /// En dessous de cet âge, un domaine est un indice fort.
  static const veryNewDomain = Duration(days: 7);

  /// En dessous de cet âge, un domaine est un indice moyen.
  static const newDomain = Duration(days: 30);

  /// En dessous de cet âge, un domaine est un indice faible.
  static const recentDomain = Duration(days: 90);

  /// Indices pour [url], d'après [evidence] ; [isOfficial] si le domaine
  /// est celui d'une marque de référence.
  List<RiskSignal> evaluate(
    ParsedUrl url,
    OnlineEvidence evidence,
    DateTime now, {
    required bool isOfficial,
  }) {
    RiskSignal signal(
      String code,
      Severity severity,
      Confidence confidence,
      String reason, {
      SignalSource source = SignalSource.onlineLookup,
      String? evidence,
    }) => RiskSignal(
      code: code,
      severity: severity,
      confidence: confidence,
      reason: reason,
      source: source,
      detectedAt: now,
      evidence: evidence,
    );

    final signals = <RiskSignal>[];

    final matches = [
      for (final result in evidence.reputation)
        if (result.status == ProviderStatus.match &&
            result.isFreshWithin(maxFeedAge))
          result,
    ];
    if (matches.isNotEmpty) {
      final types = {
        for (final result in matches)
          for (final match in result.matches) match.threatType,
      };
      final what = switch (types) {
        _ when types.length == 1 && types.single == ThreatType.phishing =>
          'comme site d’hameçonnage (faux site qui vole des identifiants)',
        _ when types.length == 1 && types.single == ThreatType.malware =>
          'comme source de logiciels malveillants',
        _ =>
          'comme site malveillant (hameçonnage, arnaque ou logiciel '
              'malveillant)',
      };
      final count = matches.length;
      signals.add(
        signal(
          UrlSignalCodes.reported,
          Severity.high,
          Confidence.high,
          count == 1
              ? 'Ce site est signalé $what par une source de sécurité '
                    'consultée en ligne.'
              : 'Ce site est signalé $what par $count sources de sécurité '
                    'consultées en ligne.',
          source: SignalSource.threatIntel,
          evidence: url.host,
        ),
      );
    }

    final registration = evidence.registration;
    final age = registration?.age;
    if (!isOfficial && registration != null && age != null) {
      final days = age.isNegative ? 0 : age.inDays;
      final date = _date(registration.registeredAt!);
      final since = switch (days) {
        0 => 'aujourd’hui',
        1 => 'hier',
        _ => 'il y a $days jours',
      };
      final reason =
          'Ce nom de domaine a été enregistré le $date ($since). Les sites '
          'd’arnaque sont souvent créés quelques jours avant d’être diffusés.';
      if (age < veryNewDomain) {
        signals.add(
          signal(
            UrlSignalCodes.domainNew,
            Severity.high,
            Confidence.high,
            reason,
          ),
        );
      } else if (age < newDomain) {
        signals.add(
          signal(
            UrlSignalCodes.domainNew,
            Severity.medium,
            Confidence.medium,
            reason,
          ),
        );
      } else if (age < recentDomain) {
        signals.add(
          signal(
            UrlSignalCodes.domainNew,
            Severity.low,
            Confidence.low,
            'Ce nom de domaine a été enregistré le $date, il y a moins de '
            'trois mois.',
          ),
        );
      }
    }

    if (evidence.resolution?.status == LookupStatus.notFound) {
      signals.add(
        signal(
          UrlSignalCodes.domainNotFound,
          Severity.low,
          Confidence.medium,
          'Ce nom de site n’existe pas (ou plus) sur Internet : la page ne '
          'peut pas s’ouvrir. Un lien d’arnaque déjà fermé ressemble souvent '
          'à cela.',
          evidence: url.host,
        ),
      );
    }
    return signals;
  }

  static String _date(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(utc.day)}/${two(utc.month)}/${utc.year}';
  }
}
