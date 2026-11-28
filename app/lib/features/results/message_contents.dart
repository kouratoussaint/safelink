import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Somme en francs CFA, chiffres groupés par trois : `500 000 FCFA`.
String formatAmount(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(end - 3 < 0 ? 0 : end - 3, end));
  }
  return '${groups.join(' ')} FCFA';
}

/// Ce que contient un message, ligne par ligne : liens, numéros, codes à
/// composer, sommes d'argent. Vide si le message n'en contient aucun.
List<(IconData, String)> messageContents(
  AppLocalizations l10n,
  MessageExtraction extraction,
) {
  final amounts = extraction.amounts.map((a) => a.value).toList();
  final largest = amounts.isEmpty
      ? null
      : amounts.reduce((a, b) => a > b ? a : b);
  return [
    if (extraction.links.isNotEmpty)
      (Icons.link_rounded, l10n.contentsLinks(extraction.links.length)),
    if (extraction.phoneNumbers.isNotEmpty)
      (
        Icons.call_outlined,
        l10n.contentsPhones(extraction.phoneNumbers.length),
      ),
    if (extraction.ussdCodes.isNotEmpty)
      (Icons.dialpad_rounded, l10n.contentsCodes(extraction.ussdCodes.length)),
    if (largest != null)
      (
        Icons.payments_outlined,
        amounts.length == 1
            ? l10n.contentsAmount(formatAmount(largest))
            : l10n.contentsAmounts(amounts.length, formatAmount(largest)),
      ),
  ];
}

/// Carte « Dans ce message » : liens, numéros, codes à composer, sommes
/// d'argent repérés, chacun avec son pictogramme.
class MessageContentsCard extends StatelessWidget {
  const new({required this.extraction, super.key});

  final MessageExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = messageContents(l10n, extraction);
    final primary = theme.colorScheme.primary;
    return SoftCard(
      child: Semantics(
        container: true,
        label: l10n.contentsSemantics(
          items.isEmpty
              ? l10n.contentsNothing
              : items.map((i) => i.$2).join(', '),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.contentsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(l10n.contentsNothing, style: theme.textTheme.bodyLarge),
              for (final (icon, text) in items)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      PictoBadge(icon: icon, color: primary, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyLarge),
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
