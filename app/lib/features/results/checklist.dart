import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Famille de contrôles : les codes d'indices qui la concernent et ses deux
/// libellés (rien trouvé, quelque chose trouvé).
final class CheckFamily {
  /// Crée une famille.
  const new(this.id, this.codes, this.ok, this.issue);

  /// Identifiant stable.
  final String id;

  /// Codes d'indices rattachés.
  final Set<String> codes;

  /// Libellé quand rien n'a été trouvé.
  final String Function(AppLocalizations l10n) ok;

  /// Libellé quand un indice a été trouvé.
  final String Function(AppLocalizations l10n) issue;
}

/// Contrôles des liens, dans l'ordre d'affichage. Chaque code d'indice de
/// lien appartient à exactement une famille (vérifié par les tests).
final List<CheckFamily> urlCheckFamilies = [
  CheckFamily(
    'ADDRESS',
    const {
      UrlSignalCodes.credentialsDeceptive,
      UrlSignalCodes.credentials,
      UrlSignalCodes.ipLiteral,
      UrlSignalCodes.ipUnusualNotation,
      UrlSignalCodes.encodedHost,
      UrlSignalCodes.invisibleCharacters,
      UrlSignalCodes.unusualHostCharacters,
      UrlSignalCodes.unusualSlashes,
      UrlSignalCodes.singleLabelHost,
      UrlSignalCodes.unlistedSuffix,
      UrlSignalCodes.unusualPort,
      UrlSignalCodes.manySubdomains,
    },
    (l10n) => l10n.checkAddressOk,
    (l10n) => l10n.checkAddressIssue,
  ),
  CheckFamily(
    'BRANDS',
    const {
      UrlSignalCodes.brandLookalike,
      UrlSignalCodes.brandTypo,
      UrlSignalCodes.brandDomainInSubdomain,
      UrlSignalCodes.brandInDomain,
      UrlSignalCodes.brandInSubdomain,
      UrlSignalCodes.brandInPath,
      UrlSignalCodes.brandOtherSuffix,
    },
    (l10n) => l10n.checkBrandsOk(BrandRegistry.embedded.brands.length),
    (l10n) => l10n.checkBrandsIssue,
  ),
  CheckFamily(
    'CHARACTERS',
    const {
      UrlSignalCodes.mixedScripts,
      UrlSignalCodes.imitatesLatin,
      UrlSignalCodes.internationalized,
    },
    (l10n) => l10n.checkCharactersOk,
    (l10n) => l10n.checkCharactersIssue,
  ),
  CheckFamily(
    'BAIT',
    const {UrlSignalCodes.baitWords},
    (l10n) => l10n.checkBaitOk,
    (l10n) => l10n.checkBaitIssue,
  ),
  CheckFamily(
    'DESTINATION',
    const {
      UrlSignalCodes.shortener,
      UrlSignalCodes.redirectParameter,
      UrlSignalCodes.userContent,
      UrlSignalCodes.sharedHosting,
    },
    (l10n) => l10n.checkDestinationOk,
    (l10n) => l10n.checkDestinationIssue,
  ),
  CheckFamily(
    'DOWNLOAD',
    const {UrlSignalCodes.apkDownload},
    (l10n) => l10n.checkDownloadOk,
    (l10n) => l10n.checkDownloadIssue,
  ),
  CheckFamily(
    'ENCRYPTION',
    const {UrlSignalCodes.unencrypted},
    (l10n) => l10n.checkEncryptionOk,
    (l10n) => l10n.checkEncryptionIssue,
  ),
  CheckFamily(
    'REPUTATION',
    const {UrlSignalCodes.reported},
    (l10n) => l10n.checkReputationOk,
    (l10n) => l10n.checkReputationIssue,
  ),
  CheckFamily(
    'AGE',
    const {UrlSignalCodes.domainNew},
    (l10n) => l10n.checkAgeOk,
    (l10n) => l10n.checkAgeIssue,
  ),
  CheckFamily(
    'EXISTS',
    const {UrlSignalCodes.domainNotFound},
    (l10n) => l10n.checkExistsOk,
    (l10n) => l10n.checkExistsIssue,
  ),
];

/// Contrôles du texte d'un message, par catégorie d'indices.
final Map<MessageSignalCategory, CheckFamily> messageCheckFamilies = {
  for (final category in MessageSignalCategory.values)
    category: CheckFamily(
      category.name,
      {
        for (final MapEntry(key: code, value: of)
            in MessageSignalCodes.categories.entries)
          if (of == category) code,
      },
      (l10n) => switch (category) {
        MessageSignalCategory.credentials => l10n.checkCredentialsOk,
        MessageSignalCategory.payment => l10n.checkPaymentOk,
        MessageSignalCategory.prize => l10n.checkPrizeOk,
        MessageSignalCategory.accountThreat => l10n.checkThreatOk,
        MessageSignalCategory.impersonation => l10n.checkImpersonationOk,
        MessageSignalCategory.offChannel => l10n.checkOffChannelOk,
        MessageSignalCategory.urgency => l10n.checkUrgencyOk,
        MessageSignalCategory.deceptiveLink => l10n.checkDeceptiveLinkOk,
        MessageSignalCategory.mistakenTransfer => l10n.checkMistakenTransferOk,
        MessageSignalCategory.ussdTransfer => l10n.checkUssdOk,
      },
      (l10n) => switch (category) {
        MessageSignalCategory.credentials => l10n.checkCredentialsIssue,
        MessageSignalCategory.payment => l10n.checkPaymentIssue,
        MessageSignalCategory.prize => l10n.checkPrizeIssue,
        MessageSignalCategory.accountThreat => l10n.checkThreatIssue,
        MessageSignalCategory.impersonation => l10n.checkImpersonationIssue,
        MessageSignalCategory.offChannel => l10n.checkOffChannelIssue,
        MessageSignalCategory.urgency => l10n.checkUrgencyIssue,
        MessageSignalCategory.deceptiveLink => l10n.checkDeceptiveLinkIssue,
        MessageSignalCategory.mistakenTransfer =>
          l10n.checkMistakenTransferIssue,
        MessageSignalCategory.ussdTransfer => l10n.checkUssdIssue,
      },
    ),
};

/// Ligne de la liste « Ce qui a été vérifié ».
final class CheckItem {
  /// Crée une ligne ; [worst] est la gravité la plus forte trouvée, ou
  /// `null` si rien n'a été trouvé.
  const new(this.label, this.worst);

  /// Libellé.
  final String label;

  /// Gravité la plus forte trouvée.
  final Severity? worst;
}

CheckItem _item(
  CheckFamily family,
  List<RiskSignal> signals,
  AppLocalizations l10n,
) {
  Severity? worst;
  for (final signal in signals) {
    if (family.codes.contains(signal.code) &&
        (worst == null || signal.severity.rank > worst.rank)) {
      worst = signal.severity;
    }
  }
  return CheckItem(worst == null ? family.ok(l10n) : family.issue(l10n), worst);
}

/// Contrôles d'un lien. Les contrôles en ligne n'apparaissent que s'ils ont
/// eu lieu : réputation si une source a répondu, âge si le registre a
/// donné une date, existence si le DNS a répondu.
List<CheckItem> urlChecklist(UrlAnalysisResult result, AppLocalizations l10n) {
  final reputationDone = result.providerResults.any((r) => r.isConclusive);
  final ageKnown = result.registration?.status == LookupStatus.found;
  final existenceKnown =
      result.resolution != null &&
      result.resolution!.status != LookupStatus.unavailable;
  return [
    for (final family in urlCheckFamilies)
      if (switch (family.id) {
        'REPUTATION' => reputationDone,
        'AGE' => ageKnown,
        'EXISTS' => existenceKnown,
        _ => true,
      })
        _item(family, result.signals, l10n),
  ];
}

/// Contrôles du texte d'un message.
List<CheckItem> messageChecklist(
  MessageAnalysisResult result,
  AppLocalizations l10n,
) => [
  for (final family in messageCheckFamilies.values)
    _item(family, result.signals, l10n),
];

/// Section « Ce qui a été vérifié ».
class ChecklistSection extends StatelessWidget {
  const new({required this.items, super.key});

  final List<CheckItem> items;

  /// Liste d'un résultat ; vide pour une adresse non analysable.
  static List<CheckItem> of(AnalysisOutcome outcome, AppLocalizations l10n) =>
      switch (outcome) {
        LinkOutcome(:final result) =>
          result.url == null ? const [] : urlChecklist(result, l10n),
        MessageOutcome(:final result) =>
          result.message.verdict == MessageVerdict.invalidMessage
              ? const []
              : messageChecklist(result.message, l10n),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.checklistTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        item.worst == null
                            ? Icons.check_circle_outline
                            : VerdictPresentation.iconOf(
                                VerdictPresentation.levelOfSeverity(
                                  item.worst!,
                                ),
                              ),
                        color: VerdictPresentation.colorOf(
                          context,
                          item.worst == null
                              ? RiskLevel.nothingObvious
                              : VerdictPresentation.levelOfSeverity(
                                  item.worst!,
                                ),
                        ),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
