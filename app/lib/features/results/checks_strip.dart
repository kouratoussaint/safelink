import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Ce qui a été vérifié, en pastilles sous le verdict : « Sur le
/// téléphone » (toujours), puis « En ligne », cochée si des services ont
/// répondu, sinon « pas de réponse » ou « désactivée ». Rien pour la
/// partie en ligne quand elle ne s'applique pas (texte sans lien).
class ChecksStrip extends StatelessWidget {
  const new({required this.online, super.key});

  /// État de la vérification en ligne.
  final OnlineStatus online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (online) {
      OnlineStatus.done => l10n.checksSemanticsBoth,
      OnlineStatus.unreachable => l10n.checksSemanticsNoAnswer,
      OnlineStatus.notRequested => l10n.checksSemanticsOff,
      OnlineStatus.notApplicable => l10n.checksSemanticsPhone,
    };
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            CheckChip(
              icon: Icons.phone_android_rounded,
              label: l10n.checksPhone,
              done: true,
            ),
            switch (online) {
              OnlineStatus.done => CheckChip(
                icon: Icons.public_rounded,
                label: l10n.checksOnline,
                done: true,
              ),
              OnlineStatus.unreachable => CheckChip(
                icon: Icons.public_off_rounded,
                label: l10n.checksOnlineNoAnswer,
                done: false,
              ),
              OnlineStatus.notRequested => CheckChip(
                icon: Icons.public_off_rounded,
                label: l10n.checksOnlineOff,
                done: false,
              ),
              OnlineStatus.notApplicable => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

/// Pastille d'une vérification : coche verte si faite ; sinon, pastille
/// neutre sans coche. [working] : en cours (points de suspension).
class CheckChip extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.done,
    this.working = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool done;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: done ? colors.successSoft : colors.neutralSoft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
          if (done || working) ...[
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: done
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('done'),
                      size: 20,
                      color: colors.success,
                    )
                  : const Icon(
                      Icons.more_horiz_rounded,
                      key: ValueKey('working'),
                      size: 20,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
