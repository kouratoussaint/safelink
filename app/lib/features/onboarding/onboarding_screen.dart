import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/results/listen_button.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Présentation de première ouverture, en quatre étapes : mission, limites,
/// confidentialité, puis choix de la vérification en ligne. Aucun compte,
/// aucune autorisation Android demandée.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 4;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() => _controller.nextPage(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  /// Dernière étape : retient le choix pour la vérification en ligne.
  Future<void> _finish({required bool online}) async {
    await ref.read(onlineChoiceProvider.notifier).select(enabled: online);
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      _OnboardingPage(
        icon: Icons.travel_explore,
        title: l10n.onboardingMissionTitle,
        body: l10n.onboardingMissionBody,
        points: [l10n.onboardingMissionPoint1, l10n.onboardingMissionPoint2],
        showMark: true,
      ),
      _OnboardingPage(
        icon: Icons.rule,
        title: l10n.onboardingLimitsTitle,
        body: l10n.onboardingLimitsBody,
        points: [
          l10n.onboardingLimitsPoint1,
          l10n.onboardingLimitsPoint2,
          l10n.onboardingLimitsPoint3,
        ],
      ),
      _OnboardingPage(
        icon: Icons.lock_outline,
        title: l10n.onboardingPrivacyTitle,
        body: l10n.onboardingPrivacyBody,
        points: [
          l10n.onboardingPrivacyPoint1,
          l10n.onboardingPrivacyPoint2,
          l10n.onboardingPrivacyPoint3,
        ],
      ),
      _OnboardingPage(
        icon: Icons.travel_explore,
        title: l10n.onboardingOnlineTitle,
        body: l10n.onboardingOnlineBody,
        points: ref.watch(googleEnabledProvider)
            ? [
                l10n.onboardingOnlineGooglePoint1,
                l10n.onboardingOnlineGooglePoint2,
                l10n.onboardingOnlinePoint3,
              ]
            : [
                l10n.onboardingOnlinePoint1,
                l10n.onboardingOnlinePoint2,
                l10n.onboardingOnlinePoint3,
              ],
      ),
    ];
    final last = _page == _pageCount - 1;
    return PopScope<Object?>(
      // Retour revient à l'étape précédente ; sur la première, il ferme
      // l'application comme d'habitude.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _controller.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Dots(
                      page: _page,
                      count: _pageCount,
                      label: l10n.onboardingStep(_page + 1, _pageCount),
                    ),
                    const SizedBox(height: 16),
                    if (last) ...[
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: () => _finish(online: true),
                        child: Text(l10n.onboardingOnlineEnable),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _finish(online: false),
                        child: Text(l10n.onboardingOnlineDecline),
                      ),
                    ] else
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: _next,
                        child: Text(l10n.onboardingNext),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Étapes de la présentation : un point par étape, l'étape courante
/// allongée ; « Étape 1 sur 4 » en petit dessous.
class _Dots extends StatelessWidget {
  const new({required this.page, required this.count, required this.label});

  final int page;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: duration,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
    this.showMark = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final primary = theme.colorScheme.primary;
    final speech = [title, body, ...points].map(spokenSentence).join(' ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: [
        Appear(
          child: Center(
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 188,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: 0.06),
                      ),
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: 0.10),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: showMark
                          ? const SafeLinkMark(size: 60)
                          : Icon(icon, size: 46, color: primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Center(child: ListenButton(text: speech)),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Column(
            children: [
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(point, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
