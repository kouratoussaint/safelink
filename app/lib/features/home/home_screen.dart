import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/motion/appear.dart';
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
            _HomeHero(tagline: l10n.tagline, title: l10n.homeTitle),
            const SizedBox(height: 20),
            Text(l10n.homeModeLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ModeTiles(
              selected: _kind,
              onSelected: (kind) => setState(() => _kind = kind),
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
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.content_paste_rounded),
              label: Text(l10n.homePaste),
              onPressed: _paste,
            ),
            const SizedBox(height: 12),
            AnimatedScale(
              scale: _canAnalyze ? 1 : 0.97,
              duration: const Duration(milliseconds: 200),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  textStyle: theme.textTheme.titleMedium,
                ),
                icon: const Icon(Icons.shield_outlined, size: 28),
                label: Text(
                  isLink ? l10n.homeAnalyzeLink : l10n.homeAnalyzeMessage,
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

/// En-tête animé : le bouclier SafeLink apparaît en rebondissant, entouré
/// d'une onde.
class _HomeHero extends StatefulWidget {
  const new({required this.tagline, required this.title});

  final String tagline;
  final String title;

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final pop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    );
    final wave = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    );
    return Row(
      children: [
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: 84,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60 + 24 * wave.value,
                    height: 60 + 24 * wave.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.18 * (1 - wave.value)),
                    ),
                  ),
                  Transform.scale(
                    scale: pop.value.clamp(0, 1.3),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                      ),
                      alignment: Alignment.center,
                      child: const SafeLinkMark(size: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tagline,
                style: theme.textTheme.titleMedium?.copyWith(color: primary),
              ),
              const SizedBox(height: 4),
              Text(widget.title, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ],
    );
  }
}

/// Deux grandes vignettes pour choisir : un lien ou un message.
class _ModeTiles extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final AnalysisKind selected;
  final ValueChanged<AnalysisKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tiles = [
      _ModeTile(
        icon: Icons.link_rounded,
        label: l10n.homeModeLink,
        hint: l10n.homeModeLinkHint,
        selected: selected == AnalysisKind.link,
        onTap: () => onSelected(AnalysisKind.link),
      ),
      _ModeTile(
        icon: Icons.sms_outlined,
        label: l10n.homeModeMessage,
        hint: l10n.homeModeMessageHint,
        selected: selected == AnalysisKind.message,
        onTap: () => onSelected(AnalysisKind.message),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 300 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tiles[0], const SizedBox(height: 8), tiles[1]],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ],
          ),
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: AnimatedScale(
                      scale: selected ? 1.12 : 1,
                      duration: duration,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        icon,
                        size: 40,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
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
