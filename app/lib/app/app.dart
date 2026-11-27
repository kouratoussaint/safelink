import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/router.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/core/theme/app_theme.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Racine de l'application SafeLink.
class SafeLinkApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // Matériel, Cupertino et widgets : tous traduits en français.
        ...GlobalMaterialLocalizations.delegates,
      ],
    );
  }
}
