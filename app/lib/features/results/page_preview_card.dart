import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/online/page_preview.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Photo d'une page prise par Google ; aucune nouvelle tentative
/// automatique.
// Le type de famille n'est pas exporté par Riverpod.
// ignore: specify_nonobvious_property_types
final pagePreviewProvider = FutureProvider.autoDispose
    .family<PagePreview, String>((ref, url) {
      final client = ref.watch(pagePreviewClientProvider);
      if (client == null) throw const PagePreviewException('UNAVAILABLE');
      return client.capture(url);
    }, retry: (_, _) => null);

/// Aperçu de la page d'un lien : photo prise par les serveurs de Google
/// (le téléphone ne contacte jamais le site), domaine réel, destination
/// finale après redirection.
///
/// Prise automatiquement si la vérification en ligne est activée, sauf
/// pour un lien qui porte un code personnel (jeton, numéro…), qu'une visite
/// pourrait utiliser : l'utilisateur décide alors.
class PagePreviewCard extends ConsumerStatefulWidget {
  const new({
    required this.result,
    this.target,
    this.level,
    this.showRedirect = true,
    super.key,
  });

  final UrlAnalysisResult result;

  /// Page à photographier si ce n'est pas le lien lui-même : la vraie
  /// destination d'un lien raccourci, quand elle est connue. Google
  /// photographie alors directement la page où le lien mène, même si le
  /// lien passe par une adresse qu'un navigateur ne sait pas afficher
  /// (ouverture du Play Store, par exemple).
  final ParsedUrl? target;

  /// Niveau affiché (celui de la destination d'un lien raccourci s'il est
  /// plus grave) ; par défaut, celui de [result].
  final RiskLevel? level;

  /// Affiche la vraie destination sous la photo ; faux si elle est déjà
  /// montrée ailleurs.
  final bool showRedirect;

  /// Vrai si un aperçu peut être pris pour [result] dans ces conditions.
  static bool applies(
    UrlAnalysisResult result,
    WidgetRef ref, {
    ParsedUrl? target,
  }) {
    final url = target ?? result.url;
    return url != null &&
        url.hostType == UrlHostType.domain &&
        ref.watch(googleEnabledProvider) &&
        ref.watch(onlineChoiceProvider) == OnlineChoice.enabled;
  }

  @override
  ConsumerState<PagePreviewCard> createState() => _PagePreviewCardState();
}

class _PagePreviewCardState extends ConsumerState<PagePreviewCard> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    if (!PagePreviewCard.applies(widget.result, ref, target: widget.target)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final url = widget.target ?? widget.result.url!;
    final sensitive = UrlMasking.maskedCount(url) > 0;
    final Widget body;
    if (sensitive && !_confirmed) {
      body = _Notice(
        icon: Icons.key_outlined,
        text: l10n.previewSensitive,
        action: OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.previewSensitiveAction),
          onPressed: () => setState(() => _confirmed = true),
        ),
      );
    } else {
      final preview = ref.watch(pagePreviewProvider(url.href));
      body = switch (preview) {
        AsyncData(:final value) => _Shot(
          preview: value,
          result: widget.result,
          level: widget.level ?? widget.result.level,
          showRedirect: widget.showRedirect,
        ),
        AsyncError(:final error) => _Notice(
          icon:
              error is PagePreviewException && error.code == 'PAGE_UNREACHABLE'
              ? Icons.cloud_off_outlined
              : Icons.photo_camera_outlined,
          text:
              error is PagePreviewException && error.code == 'PAGE_UNREACHABLE'
              ? l10n.previewUnreachable
              : l10n.previewUnavailable,
          action: TextButton(
            onPressed: () => ref.invalidate(pagePreviewProvider(url.href)),
            child: Text(l10n.previewRetry),
          ),
        ),
        _ => const _Capturing(),
      };
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.previewTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(body.runtimeType), child: body),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pendant la capture : un faux écran qui « respire » et un appareil photo
/// qui clignote, sans fausse progression.
class _Capturing extends StatefulWidget {
  const new();

  @override
  State<_Capturing> createState() => _CapturingState();
}

class _CapturingState extends State<_Capturing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: l10n.previewLoading,
      child: ExcludeSemantics(
        child: Row(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
              child: Container(
                width: 72,
                height: 128,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.previewLoading, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    l10n.previewLoadingBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: SafeLinkColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shot extends StatelessWidget {
  const new({
    required this.preview,
    required this.result,
    required this.level,
    required this.showRedirect,
  });

  final PagePreview preview;
  final UrlAnalysisResult result;
  final RiskLevel level;
  final bool showRedirect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final domain =
        result.technicalDetails?.registrableDomain ??
        result.technicalDetails?.host ??
        '';
    final risky = level == RiskLevel.danger || level == RiskLevel.attention;
    final levelColor = VerdictPresentation.colorOf(context, level);
    final finalUrl = preview.finalUrl;
    final finalParsed = finalUrl == null ? null : UrlParser().parse(finalUrl);
    final finalDomain = finalParsed is ParsedUrl
        ? finalParsed.registrableDomain ?? finalParsed.host
        : null;
    final redirected =
        finalDomain != null && domain.isNotEmpty && finalDomain != domain;
    final image = Image.memory(
      preview.screenshot,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      semanticLabel: l10n.previewSemantics,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: l10n.previewEnlarge,
            child: GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  insetPadding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: InteractiveViewer(
                          child: Image.memory(
                            preview.screenshot,
                            semanticLabel: l10n.previewSemantics,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.previewClose),
                      ),
                    ],
                  ),
                ),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: risky ? levelColor : theme.colorScheme.outline,
                    width: 4,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Fausse barre d'adresse : le vrai domaine, en gros.
                    Container(
                      width: double.infinity,
                      color: risky
                          ? levelColor
                          : theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              risky ? Icons.warning_rounded : Icons.public,
                              size: 16,
                              color: risky
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              // La page photographiée : celle où le lien
                              // mène réellement.
                              finalDomain ?? domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: risky ? Colors.white : null,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        AspectRatio(aspectRatio: 0.62, child: image),
                        if (risky)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: levelColor.withValues(alpha: 0.92),
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const ExcludeSemantics(
                                    child: Icon(
                                      Icons.gpp_bad_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l10n.previewWarning,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.previewCaption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        if (redirected && showRedirect) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.alt_route, color: colors.warning),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.previewRedirect)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  finalDomain,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(l10n.previewRedirectAction),
                  onPressed: () => context.push(
                    AppRoutes.analysis,
                    extra: AnalysisRequest(AnalysisKind.link, finalUrl!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const new({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
        if (action != null)
          Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }
}
