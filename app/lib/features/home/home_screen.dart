import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/core/widgets/info_card.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Accueil : choisir « Lien » ou « Message », coller, analyser.
///
/// Le résultat s'obtient en trois actions au plus (coller, analyser). Le
/// presse-papiers n'est lu que lorsque l'utilisateur appuie sur « Coller ».
class HomeScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final _parser = UrlParser();

  AnalysisKind _kind = AnalysisKind.link;

  /// Un champ par mode : changer de mode ne perd pas le texte saisi.
  final Map<AnalysisKind, TextEditingController> _controllers = {
    AnalysisKind.link: TextEditingController(),
    AnalysisKind.message: TextEditingController(),
  };
  final _focus = FocusNode();

  TextEditingController get _controller => _controllers[_kind]!;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers.values) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _canAnalyze => _controller.text.trim().isNotEmpty;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).homeClipboardEmpty),
          ),
        );
      return;
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _analyze() {
    if (!_canAnalyze) return;
    _focus.unfocus();
    unawaited(
      context.push(
        AppRoutes.analysis,
        extra: AnalysisRequest(_kind, _controller.text),
      ),
    );
  }

  /// Adresse effectivement analysée quand le schéma est ajouté d'office.
  String? _schemePreview() {
    if (_kind != AnalysisKind.link) return null;
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    final parsed = _parser.parse(text);
    if (parsed is! ParsedUrl || parsed.hasExplicitScheme) return null;
    return UrlMasking.truncate(UrlMasking.maskedHref(parsed), 120);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final isLink = _kind == AnalysisKind.link;
    final preview = _schemePreview();
    return Scaffold(
      appBar: AppBar(
        title: const SafeLinkWordmark(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.openSettingsTooltip,
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              l10n.tagline,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.homeTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            Semantics(
              label: l10n.homeModeLabel,
              container: true,
              child: SegmentedButton<AnalysisKind>(
                segments: [
                  ButtonSegment(
                    value: AnalysisKind.link,
                    icon: const Icon(Icons.link),
                    label: Text(l10n.homeModeLink),
                  ),
                  ButtonSegment(
                    value: AnalysisKind.message,
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(l10n.homeModeMessage),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _kind = selection.single),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: ValueKey(_kind),
              controller: _controller,
              focusNode: _focus,
              keyboardType: isLink
                  ? TextInputType.url
                  : TextInputType.multiline,
              textInputAction: isLink
                  ? TextInputAction.go
                  : TextInputAction.newline,
              autocorrect: !isLink,
              enableSuggestions: !isLink,
              minLines: isLink ? 1 : 5,
              maxLines: isLink ? 4 : 12,
              onSubmitted: isLink ? (_) => _analyze() : null,
              decoration: InputDecoration(
                labelText: isLink
                    ? l10n.homeLinkFieldLabel
                    : l10n.homeMessageFieldLabel,
                hintText: isLink
                    ? l10n.homeLinkFieldHint
                    : l10n.homeMessageFieldHint,
                alignLabelWithHint: !isLink,
                border: const OutlineInputBorder(),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.homeClear,
                        onPressed: _controller.clear,
                      ),
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.homeSchemePreview(preview),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: Text(l10n.homePaste),
                  onPressed: _paste,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(
                    isLink ? l10n.homeAnalyzeLink : l10n.homeAnalyzeMessage,
                  ),
                  onPressed: _canAnalyze ? _analyze : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.phone_android_outlined,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.homeLocalNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            InfoCard(
              icon: Icons.qr_code_scanner,
              title: l10n.homeComingSoonTitle,
              body: l10n.homeComingSoon,
              accent: colors.info,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.history),
                label: Text(l10n.homeHistoryShortcut),
                onPressed: () => context.go(AppRoutes.history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
