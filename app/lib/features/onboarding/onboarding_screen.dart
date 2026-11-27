import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Présentation de première ouverture, en trois étapes : mission, limites,
/// confidentialité. Aucun compte, aucune autorisation demandée.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.onboardingStep(_page + 1, _pageCount),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        last ? l10n.onboardingStart : l10n.onboardingNext,
                      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        if (showMark)
          const Align(
            alignment: Alignment.centerLeft,
            child: SafeLinkWordmark(),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: ExcludeSemantics(
              child: Icon(icon, size: 48, color: theme.colorScheme.primary),
            ),
          ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(point, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}
