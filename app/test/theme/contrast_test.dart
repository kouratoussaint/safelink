import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/app_theme.dart';
import 'package:safelink/core/theme/brand_palette.dart';
import 'package:safelink/core/theme/contrast.dart';
import 'package:safelink/core/theme/safelink_colors.dart';

/// Seuil WCAG AA pour le texte ordinaire.
const textMinimum = 4.5;

/// Seuil WCAG AA pour les contours et icônes d'éléments interactifs.
const uiMinimum = 3.0;

void main() {
  group('contrastRatio', () {
    test('donne 21:1 pour noir sur blanc et 1:1 pour une même couleur', () {
      expect(
        contrastRatio(const Color(0xFF000000), BrandPalette.white),
        closeTo(21, 0.01),
      );
      expect(contrastRatio(BrandPalette.navy, BrandPalette.navy), 1);
    });

    test('retrouve les valeurs de l’audit pour la palette d’origine', () {
      expect(
        contrastRatio(BrandPalette.turquoise, BrandPalette.white),
        closeTo(2.26, 0.01),
      );
      expect(
        contrastRatio(BrandPalette.red, BrandPalette.navy),
        closeTo(4.49, 0.01),
      );
    });
  });

  for (final (name, scheme, colors) in [
    ('clair', AppTheme.lightScheme, SafeLinkColors.light),
    ('sombre', AppTheme.darkScheme, SafeLinkColors.dark),
  ]) {
    group('Thème $name', () {
      final backgrounds = {
        'surface': scheme.surface,
        'surfaceContainerLow': scheme.surfaceContainerLow,
        'surfaceContainer': scheme.surfaceContainer,
        'canvas': colors.canvas,
      };

      void expectText(String label, Color foreground) {
        for (final MapEntry(key: bgName, value: bg) in backgrounds.entries) {
          expect(
            contrastRatio(foreground, bg),
            greaterThanOrEqualTo(textMinimum),
            reason: '$label sur $bgName',
          );
        }
      }

      test('chaque couleur de niveau se lit sur son fond teinté', () {
        for (final (label, fg, bg) in [
          ('danger', colors.danger, colors.dangerSoft),
          ('warning', colors.warning, colors.warningSoft),
          ('success', colors.success, colors.successSoft),
          ('info', colors.info, colors.infoSoft),
          ('textSecondary', colors.textSecondary, colors.neutralSoft),
          ('onSurface/dangerSoft', scheme.onSurface, colors.dangerSoft),
          ('onSurface/warningSoft', scheme.onSurface, colors.warningSoft),
        ]) {
          expect(
            contrastRatio(fg, bg),
            greaterThanOrEqualTo(textMinimum),
            reason: label,
          );
        }
      });

      test('le texte principal et secondaire est lisible', () {
        expectText('onSurface', scheme.onSurface);
        expectText('onSurfaceVariant', scheme.onSurfaceVariant);
        expectText('textSecondary', colors.textSecondary);
      });

      test('les couleurs d’action et sémantiques sont lisibles en texte', () {
        expectText('primary', scheme.primary);
        expectText('secondary', scheme.secondary);
        expectText('error', scheme.error);
        expectText('success', colors.success);
        expectText('warning', colors.warning);
        expectText('danger', colors.danger);
        expectText('info', colors.info);
      });

      test('le texte posé sur les couleurs pleines est lisible', () {
        final pairs = {
          'onPrimary/primary': (scheme.onPrimary, scheme.primary),
          'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
          'onError/error': (scheme.onError, scheme.error),
          'onPrimaryContainer/primaryContainer': (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
          'onSecondaryContainer/secondaryContainer': (
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          'onErrorContainer/errorContainer': (
            scheme.onErrorContainer,
            scheme.errorContainer,
          ),
          'onInverseSurface/inverseSurface': (
            scheme.onInverseSurface,
            scheme.inverseSurface,
          ),
        };
        for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
          expect(
            contrastRatio(fg, bg),
            greaterThanOrEqualTo(textMinimum),
            reason: label,
          );
        }
      });

      test('les contours et l’icône sélectionnée sont perceptibles', () {
        for (final MapEntry(key: bgName, value: bg) in backgrounds.entries) {
          expect(
            contrastRatio(scheme.outline, bg),
            greaterThanOrEqualTo(uiMinimum),
            reason: 'outline sur $bgName',
          );
        }
        expect(
          contrastRatio(scheme.onSecondaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(uiMinimum),
          reason: 'icône sélectionnée sur l’indicateur de navigation',
        );
      });
    });
  }

  test('les thèmes exposent les jetons SafeLink', () {
    expect(AppTheme.light.extension<SafeLinkColors>(), SafeLinkColors.light);
    expect(AppTheme.dark.extension<SafeLinkColors>(), SafeLinkColors.dark);
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('SafeLinkColors interpole et se copie', () {
    final mid = SafeLinkColors.light.lerp(SafeLinkColors.dark, 0.5);
    expect(mid.danger, isNot(SafeLinkColors.light.danger));
    expect(SafeLinkColors.light.lerp(null, 0.5), SafeLinkColors.light);
    final copy = SafeLinkColors.light.copyWith(danger: BrandPalette.red);
    expect(copy.danger, BrandPalette.red);
    expect(copy.success, SafeLinkColors.light.success);
    expect(SafeLinkColors.light.copyWith(), isA<SafeLinkColors>());
  });
}
