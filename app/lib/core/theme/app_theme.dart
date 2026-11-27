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
    primaryContainer: Color(0xFFE3F4F1),
    onPrimaryContainer: Color(0xFF00332D),
    secondary: Color(0xFF0369A1),
    onSecondary: BrandPalette.white,
    secondaryContainer: Color(0xFFE3F4F1),
    onSecondaryContainer: Color(0xFF00483F),
    error: Color(0xFFB91C1C),
    onError: BrandPalette.white,
    errorContainer: Color(0xFFFDE2E2),
    onErrorContainer: Color(0xFF5F0B0B),
    surface: BrandPalette.white,
    onSurface: BrandPalette.navy,
    onSurfaceVariant: Color(0xFF4A5A6B),
    surfaceContainerLowest: BrandPalette.white,
    surfaceContainerLow: Color(0xFFF5F7FA),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE7ECF1),
    surfaceContainerHighest: Color(0xFFE1E7ED),
    outline: Color(0xFF6B7A8A),
    outlineVariant: Color(0xFFD5DDE5),
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
    surface: Color(0xFF0D2640),
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
    final buttonText = text.titleMedium?.merge(heading).copyWith(fontSize: 16);
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    const fieldRadius = BorderRadius.all(Radius.circular(14));
    return base.copyWith(
      scaffoldBackgroundColor: colors.canvas,
      dividerColor: colors.divider,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.merge(heading),
        headlineLarge: text.headlineLarge?.merge(heading),
        headlineMedium: text.headlineMedium?.merge(heading),
        headlineSmall: text.headlineSmall?.merge(heading),
        titleLarge: text.titleLarge?.merge(heading),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge
            ?.merge(heading)
            .copyWith(color: scheme.onSurface, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: colors.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : colors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : colors.textSecondary,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        minVerticalPadding: 12,
        titleTextStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          selectedBackgroundColor: scheme.onSurface,
          selectedForegroundColor: scheme.surface,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(0, 44),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
