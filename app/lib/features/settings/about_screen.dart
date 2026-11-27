import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/build_info.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// « À propos » : version, révision, licence et code source.
///
/// L'adresse du dépôt est affichée et copiable, mais jamais ouverte
/// automatiquement.
class AboutScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider);
    final version = info.when(
      data: (p) => '${p.version} (${p.buildNumber})',
      loading: () => l10n.aboutLoading,
      error: (_, _) => l10n.aboutVersionUnavailable,
    );
    final revision = gitRevision.isEmpty
        ? l10n.aboutRevisionLocal
        : gitRevision;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SafeLinkWordmark(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.aboutDisclaimer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SafeLinkColors.of(context).textSecondary,
                ),
              ),
            ),
            _InfoTile(label: l10n.aboutVersionLabel, value: version),
            _InfoTile(label: l10n.aboutRevisionLabel, value: revision),
            _InfoTile(
              label: l10n.aboutLicenseLabel,
              value: l10n.aboutLicenseValue,
            ),
            ListTile(
              title: Text(l10n.aboutSourceLabel),
              subtitle: const SelectableText(sourceRepositoryUrl),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.aboutCopySource,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    const ClipboardData(text: sourceRepositoryUrl),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.aboutSourceCopied)),
                  );
                },
              ),
            ),
            _InfoTile(label: l10n.aboutFontsLabel, value: l10n.aboutFontsValue),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutComponentLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: info.value?.version,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(label), subtitle: Text(value));
  }
}
