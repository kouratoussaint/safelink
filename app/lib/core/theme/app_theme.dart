import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/brand_palette.dart';
import 'package:safelink/core/theme/safelink_colors.dart';

/// Thèmes clair et sombre de SafeLink.
///
/// Les couleurs sont fixées à la main plutôt que dérivées d'une couleur
/// source, pour respecter la charte et des contrastes vérifiés par test.
abstract final class AppTheme {
  /// Police des titres.
  static const headingFont = 'Poppins';

  /// Police du texte courant.
  static const bodyFont = 'Inter';

  /// Schéma de couleurs du thème clair.
  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF00796B),
    onPrimary: BrandPalette.white,
    primaryContainer: Color(0xFFCCF3EE),
    onPrimaryContainer: Color(0xFF00332D),
    secondary: Color(0xFF0369A1),
    onSecondary: BrandPalette.white,
    secondaryContainer: Color(0xFFDCEEFB),
    onSecondaryContainer: Color(0xFF062C47),
    error: Color(0xFFB91C1C),
    onError: BrandPalette.white,
    errorContainer: Color(0xFFFDE2E2),
    onErrorContainer: Color(0xFF5F0B0B),
    surface: BrandPalette.white,
    onSurface: BrandPalette.navy,
    onSurfaceVariant: Color(0xFF475569),
    surfaceContainerLowest: BrandPalette.white,
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE8EEF4),
    surfaceContainerHighest: Color(0xFFE2E8F0),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFFCBD5E1),
    inverseSurface: BrandPalette.navy,
    onInverseSurface: BrandPalette.white,
    inversePrimary: BrandPalette.turquoise,
  );

  /// Schéma de couleurs du thème sombre, proche des maquettes.
  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BrandPalette.turquoise,
    onPrimary: BrandPalette.navy,
    primaryContainer: Color(0xFF0B4A44),
    onPrimaryContainer: Color(0xFFCFFAF3),
    secondary: BrandPalette.accentBlue,
    onSecondary: BrandPalette.navy,
    secondaryContainer: Color(0xFF123B5E),
    onSecondaryContainer: Color(0xFFDCEEFB),
    error: Color(0xFFF87171),
    onError: BrandPalette.navy,
    errorContainer: Color(0xFF5F1A1A),
    onErrorContainer: Color(0xFFFDE2E2),
    surface: BrandPalette.navy,
    onSurface: BrandPalette.white,
    onSurfaceVariant: Color(0xFFA9B8C9),
    surfaceContainerLowest: Color(0xFF06182A),
    surfaceContainerLow: Color(0xFF0B2339),
    surfaceContainer: Color(0xFF0F2A44),
    surfaceContainerHigh: Color(0xFF13314F),
    surfaceContainerHighest: Color(0xFF183A5C),
    outline: Color(0xFF7590AD),
    outlineVariant: Color(0xFF22405E),
    inverseSurface: Color(0xFFE2E8F0),
    onInverseSurface: BrandPalette.navy,
    inversePrimary: Color(0xFF00796B),
  );

  /// Thème clair.
  static ThemeData get light => _build(lightScheme, SafeLinkColors.light);

  /// Thème sombre.
  static ThemeData get dark => _build(darkScheme, SafeLinkColors.dark);

  static ThemeData _build(ColorScheme scheme, SafeLinkColors colors) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
      extensions: [colors],
    );
    const heading = TextStyle(
      fontFamily: headingFont,
      fontWeight: FontWeight.w600,
    );
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.merge(heading),
        headlineLarge: text.headlineLarge?.merge(heading),
        headlineMedium: text.headlineMedium?.merge(heading),
        headlineSmall: text.headlineSmall?.merge(heading),
        titleLarge: text.titleLarge?.merge(heading),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge
            ?.merge(heading)
            .copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
