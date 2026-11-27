import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/app/shell.dart';
import 'package:safelink/features/analysis/analysis_screen.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_screen.dart';
import 'package:safelink/features/home/home_screen.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';
import 'package:safelink/features/onboarding/onboarding_screen.dart';
import 'package:safelink/features/settings/about_screen.dart';
import 'package:safelink/features/settings/settings_screen.dart';
import 'package:safelink/features/tips/tips_screen.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Routeur de l'application : quatre onglets (Accueil, Historique, Conseils,
/// Paramètres), chacun avec sa propre pile de navigation, précédés à la
/// première ouverture d'une courte présentation.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider);
      final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!done && !onOnboarding) return AppRoutes.onboarding;
      if (done && onOnboarding) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'analyse',
                    builder: (context, state) => AnalysisScreen(
                      request: switch (state.extra) {
                        final AnalysisRequest request => request,
                        _ => null,
                      },
                    ),
                    routes: [
                      GoRoute(
                        path: 'lien',
                        builder: (context, state) => LinkResultScreen(
                          result: switch (state.extra) {
                            final UrlAnalysisResult result => result,
                            _ => null,
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tips,
                builder: (context, state) => const TipsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'a-propos',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
