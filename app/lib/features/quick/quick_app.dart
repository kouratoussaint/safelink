import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/core/theme/app_theme.dart';
import 'package:safelink/features/quick/quick_screen.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Racine du panneau rapide (ADR 0015), lancé par `quickCheckMain` dans
/// son propre moteur Flutter : même thème, mêmes réglages, même moteur
/// d'analyse et même historique que l'application, sans ses onglets.
class QuickCheckApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).quickTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const QuickCheckScreen(),
    );
  }
}
