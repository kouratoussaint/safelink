import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/app_theme.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Symbole SafeLink (bouclier et maillon), vectoriel.
class SafeLinkMark extends StatelessWidget {
  const new({this.size = 32, super.key});

  /// Côté du symbole, en pixels logiques.
  final double size;

  @override
  Widget build(BuildContext context) {
    // Sur fond clair, le maillon bleu très clair deviendrait invisible :
    // une variante dédiée le dessine en bleu nuit.
    final onLight = Theme.of(context).brightness == Brightness.light;
    return SvgPicture.asset(
      onLight
          ? 'assets/brand/safelink_mark_on_light.svg'
          : 'assets/brand/safelink_mark.svg',
      width: size,
      height: size,
      semanticsLabel: AppLocalizations.of(context).logoSemanticLabel,
    );
  }
}

/// Logo complet : symbole et nom « SafeLink » bicolore.
class SafeLinkWordmark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const style = TextStyle(
      fontFamily: AppTheme.headingFont,
      fontWeight: FontWeight.w700,
      fontSize: 22,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SafeLinkMark(),
        const SizedBox(width: 8),
        Flexible(
          child: Semantics(
            label: AppLocalizations.of(context).appTitle,
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Safe',
                    style: style.copyWith(color: scheme.onSurface),
                  ),
                  TextSpan(
                    text: 'Link',
                    style: style.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
