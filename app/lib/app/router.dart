import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/app/shell.dart';
import 'package:safelink/features/analysis/analysis_screen.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/help/examples_screen.dart';
import 'package:safelink/features/help/help_screen.dart';
import 'package:safelink/features/help/not_found_screen.dart';
import 'package:safelink/features/help/privacy_screen.dart';
import 'package:safelink/features/history/history_entry_screen.dart';
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
    // Adresse inconnue : page en français, retour à l'accueil.
    errorBuilder: (context, state) => const NotFoundScreen(),
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
                    path: 'aide',
                    builder: (context, state) => const HelpScreen(),
                    routes: [
                      GoRoute(
                        path: 'exemples',
                        builder: (context, state) => const ExamplesScreen(),
                      ),
                    ],
                  ),
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
                        builder: (context, state) => switch (state.extra) {
                          (
                            final UrlAnalysisResult result,
                            final OnlineStatus online,
                            final UrlAnalysisResult? destination,
                          ) =>
                            LinkResultScreen(
                              result: result,
                              online: online,
                              destination: destination,
                            ),
                          (
                            final UrlAnalysisResult result,
                            final OnlineStatus online,
                          ) =>
                            LinkResultScreen(result: result, online: online),
                          final UrlAnalysisResult result => LinkResultScreen(
                            result: result,
                          ),
                          _ => const LinkResultScreen(result: null),
                        },
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
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        HistoryEntryScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tips,
                builder: (context, state) => const TipsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        TipDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
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
                  GoRoute(
                    path: 'confidentialite',
                    builder: (context, state) => const PrivacyScreen(),
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
