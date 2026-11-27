import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/features/share/share_source.dart';
import 'package:safelink/features/share/shared_content.dart';

/// Ouvre les partages reçus d'autres applications.
///
/// Placé autour des onglets : il n'agit donc qu'une fois la présentation de
/// première ouverture terminée. Un partage reçu avant attend dans
/// [shareInboxProvider]. Qu'il arrive au lancement ou pendant que
/// l'application est ouverte, il est ouvert depuis l'accueil : Retour y
/// ramène.
class ShareHandler extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends ConsumerState<ShareHandler> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<SharedContent?>(shareInboxProvider, (_, next) {
      if (next != null) _schedule();
    }, fireImmediately: true);
  }

  /// La navigation attend la fin de l'image en cours : elle ne peut pas
  /// avoir lieu pendant la construction des écrans.
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _scheduled = false;
        _open();
      })
      ..ensureVisualUpdate();
  }

  void _open() {
    if (!mounted) return;
    final content = ref.read(shareInboxProvider.notifier).take();
    if (content == null) return;
    final router = GoRouter.of(context);
    switch (planShare(content)) {
      case AnalyzeShared(:final request):
        router.go(AppRoutes.analysis, extra: request);
      case final plan:
        router.go(AppRoutes.share, extra: plan);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
