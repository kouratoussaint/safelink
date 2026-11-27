import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_checker.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/safe_browsing.dart';
import 'package:safelink/features/results/result_widgets.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Âge lisible d'une date passée : « il y a 3 jours », « il y a 2 ans ».
String ageLabel(AppLocalizations l10n, Duration age) {
  final days = age.isNegative ? 0 : age.inDays;
  if (days == 0) return l10n.ageToday;
  if (days == 1) return l10n.ageYesterday;
  if (days < 60) return l10n.ageDays(days);
  if (days < 730) return l10n.ageMonths(days ~/ 30);
  return l10n.ageYears(days ~/ 365);
}

/// État de la vérification en ligne d'un lien précis, à partir de l'état
/// global de l'analyse ([overall]).
OnlineStatus linkOnlineStatus(UrlAnalysisResult result, OnlineStatus overall) {
  if (overall != OnlineStatus.done) return overall;
  final asked =
      result.providerResults.isNotEmpty ||
      result.registration != null ||
      result.resolution != null;
  if (!asked) return OnlineStatus.notApplicable;
  final answered =
      result.providerResults.any(
        (r) => r.status != ProviderStatus.unavailable,
      ) ||
      result.resolution?.status != LookupStatus.unavailable;
  return answered ? OnlineStatus.done : OnlineStatus.unreachable;
}

/// Proposition d'activer la vérification en ligne, tant que l'utilisateur
/// n'a pas choisi. L'activer relance l'analyse affichée.
class OnlineOfferCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(onlineChoiceProvider) != OnlineChoice.undecided) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choice = ref.read(onlineChoiceProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.travel_explore,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.onlineOfferTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ref.watch(googleEnabledProvider)
                  ? l10n.onlineOfferGoogleBody
                  : l10n.onlineOfferBody,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => choice.select(enabled: false),
                  child: Text(l10n.onlineDecline),
                ),
                FilledButton(
                  onPressed: () => choice.select(enabled: true),
                  child: Text(l10n.onlineEnable),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section « Vérifications en ligne » du résultat d'un lien.
class OnlineSection extends ConsumerWidget {
  const new({
    required this.result,
    required this.status,
    this.onRetry,
    super.key,
  });

  final UrlAnalysisResult result;

  /// État de la vérification pour ce lien.
  final OnlineStatus status;

  /// Relance l'analyse (pas de réponse).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final choice = ref.watch(onlineChoiceProvider);
    final children = <Widget>[];

    switch (status) {
      case OnlineStatus.notRequested:
        children.add(Text(l10n.onlineDisabled));
        if (choice == OnlineChoice.disabled) {
          children.add(
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref
                    .read(onlineChoiceProvider.notifier)
                    .select(enabled: true),
                child: Text(l10n.onlineDisabledAction),
              ),
            ),
          );
        }
      case OnlineStatus.notApplicable:
        children.add(Text(l10n.onlineNotApplicable));
      case OnlineStatus.unreachable:
        children.add(Text(l10n.onlineUnreachable));
        if (onRetry != null) {
          children.add(
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: Text(l10n.onlineRetry),
              ),
            ),
          );
        }
      case OnlineStatus.done:
        for (final source in ReputationSource.values) {
          final answer = result.providerResults
              .where((r) => r.providerId == source.providerId)
              .firstOrNull;
          final (label, level) = switch (answer?.status) {
            ProviderStatus.match => (l10n.onlineReported, RiskLevel.danger),
            ProviderStatus.noMatch => (
              l10n.onlineNotReported,
              RiskLevel.nothingObvious,
            ),
            _ => (l10n.onlineNoAnswer, RiskLevel.notAnalyzable),
          };
          children.add(_Row(title: source.label, value: label, level: level));
        }
        final google = result.providerResults
            .where((r) => r.providerId == SafeBrowsingClient.providerId)
            .firstOrNull;
        if (google != null) {
          final (label, level) = switch (google.status) {
            ProviderStatus.match => (
              l10n.onlineGoogleReported,
              RiskLevel.danger,
            ),
            ProviderStatus.noMatch => (
              l10n.onlineNotReported,
              RiskLevel.nothingObvious,
            ),
            _ => (l10n.onlineNoAnswer, RiskLevel.notAnalyzable),
          };
          children.add(
            _Row(title: l10n.onlineSourceGoogle, value: label, level: level),
          );
        }
        final registration = result.registration;
        children.add(
          _Row(
            title: l10n.onlineDomainCreated,
            value: switch (registration?.status) {
              LookupStatus.found => l10n.onlineDomainCreatedOn(
                formatDay(registration!.registeredAt!),
                ageLabel(l10n, registration.age!),
              ),
              LookupStatus.notFound => l10n.onlineDomainNotRegistered,
              _ => l10n.onlineDomainUnknown,
            },
            level:
                result.signals.any(
                  (s) =>
                      s.code == UrlSignalCodes.domainNew &&
                      s.severity.rank >= Severity.medium.rank,
                )
                ? RiskLevel.attention
                : registration?.status == LookupStatus.found
                ? RiskLevel.nothingObvious
                : RiskLevel.notAnalyzable,
          ),
        );
        final resolution = result.resolution?.status;
        children.add(
          _Row(
            title: l10n.onlineSiteExists,
            value: switch (resolution) {
              LookupStatus.found => l10n.onlineSiteFound,
              LookupStatus.notFound => l10n.onlineSiteNotFound,
              _ => l10n.onlineSiteUnknown,
            },
            level: switch (resolution) {
              LookupStatus.found => RiskLevel.nothingObvious,
              LookupStatus.notFound => RiskLevel.uncertain,
              _ => RiskLevel.notAnalyzable,
            },
          ),
        );
        if (google != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.onlineGoogleAttribution,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          );
        }
        final host = result.technicalDetails?.host;
        if (host != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                l10n.onlineSentNote(host),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          );
        }
    }
    return ResultSection(title: l10n.onlineSectionTitle, children: children);
  }
}

class _Row extends StatelessWidget {
  const new({required this.title, required this.value, required this.level});

  final String title;
  final String value;
  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = VerdictPresentation.colorOf(context, level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              level == RiskLevel.nothingObvious
                  ? Icons.check_circle_outline
                  : VerdictPresentation.iconOf(level),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
