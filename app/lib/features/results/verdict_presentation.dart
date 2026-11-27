import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Présentation d'un verdict : libellé, sous-titre, icône et couleur.
///
/// La couleur n'est jamais seule : le libellé et l'icône disent la même
/// chose (cahier des charges, F07).
@immutable
final class VerdictPresentation {
  /// Crée une présentation.
  const new({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.level,
    this.simple = '',
  });

  /// Présentation du verdict d'un lien.
  factory forUrl(UrlAnalysisResult result, AppLocalizations l10n) =>
      VerdictPresentation.forUrlVerdict(
        result.verdict,
        l10n,
        quiet: result.signals.every((s) => s.severity.rank < 2),
        invalidReason: result.failure?.error.description,
      );

  /// Présentation d'un verdict de lien enregistré ; [quiet] si aucun indice
  /// moyen ou fort n'a été relevé.
  factory forUrlVerdict(
    UrlVerdict verdict,
    AppLocalizations l10n, {
    bool quiet = true,
    String? invalidReason,
  }) => switch (verdict) {
    UrlVerdict.knownThreat => VerdictPresentation(
      label: l10n.verdictKnownThreat,
      subtitle: l10n.subtitleKnownThreat,
      icon: Icons.gpp_bad_outlined,
      level: verdict.level,
      simple: l10n.simpleKnownThreat,
    ),
    UrlVerdict.suspicious => VerdictPresentation(
      label: l10n.verdictSuspicious,
      subtitle: l10n.subtitleSuspicious,
      icon: Icons.warning_amber_rounded,
      level: verdict.level,
      simple: l10n.simpleSuspicious,
    ),
    UrlVerdict.noKnownThreat => VerdictPresentation(
      label: l10n.verdictNoKnownThreat,
      subtitle: l10n.subtitleNoKnownThreat,
      icon: Icons.shield_outlined,
      level: verdict.level,
      simple: l10n.simpleNoKnownThreat,
    ),
    UrlVerdict.inconclusive => VerdictPresentation(
      label: l10n.verdictInconclusive,
      subtitle: quiet
          ? l10n.subtitleInconclusiveQuiet
          : l10n.subtitleInconclusiveSignals,
      icon: Icons.help_outline,
      level: verdict.level,
      simple: l10n.simpleInconclusive,
    ),
    UrlVerdict.invalid => VerdictPresentation(
      label: l10n.verdictInvalid,
      subtitle: invalidReason ?? '',
      icon: Icons.block_outlined,
      level: verdict.level,
      simple: l10n.simpleInvalid,
    ),
  };

  /// Présentation du verdict du texte d'un message.
  factory forMessage(MessageAnalysisResult result, AppLocalizations l10n) =>
      VerdictPresentation.forMessageVerdict(
        result.verdict,
        l10n,
        invalidReason: result.limitations.firstOrNull?.description,
      );

  /// Présentation d'un verdict de message enregistré.
  factory forMessageVerdict(
    MessageVerdict verdict,
    AppLocalizations l10n, {
    String? invalidReason,
  }) => switch (verdict) {
    MessageVerdict.highRiskMessage => VerdictPresentation(
      label: l10n.verdictHighRisk,
      subtitle: l10n.subtitleHighRisk,
      icon: Icons.gpp_bad_outlined,
      level: verdict.level,
      simple: l10n.simpleHighRisk,
    ),
    MessageVerdict.suspiciousMessage => VerdictPresentation(
      label: l10n.verdictSuspiciousMessage,
      subtitle: l10n.subtitleSuspiciousMessage,
      icon: Icons.warning_amber_rounded,
      level: verdict.level,
      simple: l10n.simpleSuspiciousMessage,
    ),
    MessageVerdict.noObviousSignals => VerdictPresentation(
      label: l10n.verdictNoObviousSignals,
      subtitle: l10n.subtitleNoObviousSignals,
      icon: Icons.shield_outlined,
      level: verdict.level,
      simple: l10n.simpleNoObviousSignals,
    ),
    MessageVerdict.inconclusiveMessage => VerdictPresentation(
      label: l10n.verdictInconclusiveMessage,
      subtitle: l10n.subtitleInconclusiveMessage,
      icon: Icons.help_outline,
      level: verdict.level,
      simple: l10n.simpleInconclusiveMessage,
    ),
    MessageVerdict.invalidMessage => VerdictPresentation(
      label: l10n.verdictInvalidMessage,
      subtitle: invalidReason ?? '',
      icon: Icons.block_outlined,
      level: verdict.level,
      simple: l10n.simpleInvalidMessage,
    ),
  };

  /// Présentation d'un lien, aggravée par sa vraie [destination] si le lien
  /// est raccourci et que la destination est plus grave.
  factory forLinkWithDestination(
    UrlAnalysisResult link,
    UrlAnalysisResult? destination,
    AppLocalizations l10n,
  ) {
    final own = VerdictPresentation.forUrl(link, l10n);
    if (destination == null || destination.level.rank <= link.level.rank) {
      return own;
    }
    final dest = VerdictPresentation.forUrl(destination, l10n);
    return VerdictPresentation(
      label: dest.label,
      subtitle: dest.subtitle,
      icon: dest.icon,
      level: dest.level,
      simple: switch (dest.level) {
        RiskLevel.danger => l10n.simpleShortDanger,
        RiskLevel.attention => l10n.simpleShortAttention,
        _ => dest.simple,
      },
    );
  }

  /// Présentation de la synthèse d'un message et de ses liens.
  factory forCombined(RiskLevel level, AppLocalizations l10n) =>
      VerdictPresentation(
        label: l10n.combinedTitle(levelLabel(l10n, level)),
        subtitle: l10n.combinedBody,
        icon: iconOf(level),
        level: level,
        simple: switch (level) {
          RiskLevel.danger => l10n.simpleCombinedDanger,
          RiskLevel.attention => l10n.simpleCombinedAttention,
          RiskLevel.uncertain => l10n.simpleCombinedUncertain,
          RiskLevel.nothingObvious => l10n.simpleCombinedNothingObvious,
          RiskLevel.notAnalyzable => l10n.simpleCombinedNotAnalyzable,
        },
      );

  /// Libellé du verdict.
  final String label;

  /// Précision affichée sous le libellé.
  final String subtitle;

  /// Icône du verdict.
  final IconData icon;

  /// Niveau de synthèse, qui fixe la couleur.
  final RiskLevel level;

  /// Phrase courte en mots simples, affichée hors du mode expert.
  final String simple;

  /// Mot d'alerte, très court, affiché en grand.
  static String heroWord(AppLocalizations l10n, RiskLevel level) =>
      switch (level) {
        RiskLevel.danger => l10n.heroDanger,
        RiskLevel.attention => l10n.heroAttention,
        RiskLevel.uncertain => l10n.heroUncertain,
        RiskLevel.nothingObvious => l10n.heroNothingObvious,
        RiskLevel.notAnalyzable => l10n.heroNotAnalyzable,
      };

  /// Couleur du niveau [level] dans le thème courant.
  static Color colorOf(BuildContext context, RiskLevel level) {
    final colors = SafeLinkColors.of(context);
    return switch (level) {
      RiskLevel.danger => colors.danger,
      RiskLevel.attention => colors.warning,
      RiskLevel.uncertain => colors.info,
      RiskLevel.nothingObvious => colors.success,
      RiskLevel.notAnalyzable => colors.textSecondary,
    };
  }

  /// Icône du niveau [level].
  static IconData iconOf(RiskLevel level) => switch (level) {
    RiskLevel.danger => Icons.gpp_bad_outlined,
    RiskLevel.attention => Icons.warning_amber_rounded,
    RiskLevel.uncertain => Icons.help_outline,
    RiskLevel.nothingObvious => Icons.shield_outlined,
    RiskLevel.notAnalyzable => Icons.block_outlined,
  };

  /// Libellé court du niveau [level].
  static String levelLabel(AppLocalizations l10n, RiskLevel level) =>
      switch (level) {
        RiskLevel.danger => l10n.levelDanger,
        RiskLevel.attention => l10n.levelAttention,
        RiskLevel.uncertain => l10n.levelUncertain,
        RiskLevel.nothingObvious => l10n.levelNothingObvious,
        RiskLevel.notAnalyzable => l10n.levelNotAnalyzable,
      };

  /// Libellé de la confiance.
  static String confidenceLabel(AppLocalizations l10n, Confidence confidence) =>
      l10n.confidence(switch (confidence) {
        Confidence.low => l10n.confidenceLow,
        Confidence.medium => l10n.confidenceMedium,
        Confidence.high => l10n.confidenceHigh,
      });

  /// Libellé de la gravité d'un indice.
  static String severityLabel(AppLocalizations l10n, Severity severity) =>
      switch (severity) {
        Severity.high => l10n.severityHigh,
        Severity.medium => l10n.severityMedium,
        Severity.low => l10n.severityLow,
        Severity.info => l10n.severityInfo,
      };

  /// Niveau de synthèse correspondant à la gravité d'un indice, pour sa
  /// couleur et son icône.
  static RiskLevel levelOfSeverity(Severity severity) => switch (severity) {
    Severity.high => RiskLevel.danger,
    Severity.medium => RiskLevel.attention,
    Severity.low => RiskLevel.uncertain,
    Severity.info => RiskLevel.notAnalyzable,
  };

  /// Libellé de la nature d'un rapprochement de marque.
  static String brandKindLabel(AppLocalizations l10n, BrandMatchKind kind) =>
      switch (kind) {
        BrandMatchKind.official => l10n.brandKindOfficial,
        BrandMatchKind.officialDomainInSubdomain =>
          l10n.brandKindDomainInSubdomain,
        BrandMatchKind.lookalike => l10n.brandKindLookalike,
        BrandMatchKind.typo => l10n.brandKindTypo,
        BrandMatchKind.keywordInDomain => l10n.brandKindInDomain,
        BrandMatchKind.keywordInSubdomain => l10n.brandKindInSubdomain,
        BrandMatchKind.sameNameOtherSuffix => l10n.brandKindOtherSuffix,
      };
}
