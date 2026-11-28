import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/theme/app_theme.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/brand.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/reason_tiles.dart';
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
    final field = TextField(
      key: ValueKey(_kind),
      controller: _controller,
      focusNode: _focus,
      keyboardType: isLink ? TextInputType.url : TextInputType.multiline,
      textInputAction: isLink ? TextInputAction.go : TextInputAction.newline,
      autocorrect: !isLink,
      enableSuggestions: !isLink,
      minLines: isLink ? 1 : 4,
      maxLines: isLink ? 4 : 10,
      onSubmitted: isLink ? (_) => _analyze() : null,
      decoration: InputDecoration(
        labelText: isLink
            ? l10n.homeLinkFieldLabel
            : l10n.homeMessageFieldLabel,
        hintText: isLink ? l10n.homeLinkFieldHint : l10n.homeMessageFieldHint,
        alignLabelWithHint: !isLink,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l10n.homeClear,
                onPressed: _controller.clear,
              ),
      ),
    );
    final paste = FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
      icon: const Icon(Icons.content_paste_rounded, size: 20),
      label: Text(l10n.homePaste),
      onPressed: _paste,
    );
    return Scaffold(
      appBar: AppBar(
        title: const SafeLinkWordmark(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: l10n.homeHelpTooltip,
              onPressed: () => context.go(AppRoutes.help),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Appear(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.tagline,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Appear(
              index: 1,
              child: _ModeSwitch(
                selected: _kind,
                onSelected: (kind) => setState(() => _kind = kind),
              ),
            ),
            const SizedBox(height: 16),
            Appear(
              index: 2,
              child: SoftCard(
                radius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    if (preview != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.homeSchemePreview(preview),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    paste,
                    const SizedBox(height: 14),
                    AnimatedScale(
                      scale: _canAnalyze ? 1 : 0.98,
                      duration: const Duration(milliseconds: 200),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: AppTheme.headingFont,
                            fontSize: 17,
                          ),
                        ),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: Text(
                          isLink
                              ? l10n.homeAnalyzeLink
                              : l10n.homeAnalyzeMessage,
                        ),
                        onPressed: _canAnalyze ? _analyze : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.phone_android_outlined,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.homeLocalNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Appear(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroupLabel(l10n.homeQuickTitle),
                  GroupedCard(
                    children: [
                      CardRow(
                        leading: PictoBadge(
                          icon: Icons.share_rounded,
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                        title: l10n.homeShareRowTitle,
                        subtitle: l10n.homeShareRowSubtitle,
                        onTap: () => context.go(AppRoutes.help),
                      ),
                      CardRow(
                        leading: PictoBadge(
                          icon: Icons.science_outlined,
                          color: colors.info,
                          size: 40,
                        ),
                        title: l10n.homeExamples,
                        subtitle: l10n.homeExamplesSubtitle,
                        onTap: () => context.go(AppRoutes.examples),
                      ),
                      CardRow(
                        leading: PictoBadge(
                          icon: Icons.qr_code_scanner_rounded,
                          color: colors.textSecondary,
                          size: 40,
                        ),
                        title: l10n.homeQrTitle,
                        subtitle: l10n.homeComingSoon,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix « Lien » ou « Message » : deux segments sur une piste grise, le
/// segment choisi en blanc, légèrement surélevé.
class _ModeSwitch extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final AnalysisKind selected;
  final ValueChanged<AnalysisKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SafeLinkColors.of(context);
    return Semantics(
      label: l10n.homeModeLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            for (final (kind, icon, label) in [
              (AnalysisKind.link, Icons.link_rounded, l10n.homeModeLink),
              (AnalysisKind.message, Icons.sms_outlined, l10n.homeModeMessage),
            ])
              Expanded(
                child: _Segment(
                  icon: icon,
                  label: label,
                  selected: selected == kind,
                  onTap: () => onSelected(kind),
                  shadow: colors.cardShadow,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.shadow,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? shadow : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? scheme.primary
                          : SafeLinkColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? scheme.onSurface
                            : SafeLinkColors.of(context).textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
