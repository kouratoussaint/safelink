import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/tab_history.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Structure commune aux quatre onglets, avec la barre de navigation.
///
/// Gère aussi le bouton Retour d'Android :
/// 1. il revient d'abord en arrière dans l'onglet courant (par exemple de
///    « À propos » vers « Paramètres ») ;
/// 2. puis vers les onglets visités précédemment, jusqu'à l'Accueil ;
/// 3. sur l'Accueil, un premier appui affiche « Appuyez de nouveau sur
///    Retour pour quitter SafeLink » ; un second appui dans les
///    [exitConfirmationDelay] ferme l'application.
class AppShell extends StatefulWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// Délai pendant lequel un second appui sur Retour ferme l'application.
  static const exitConfirmationDelay = Duration(seconds: 2);

  /// Grossissement maximal accordé à la barre de navigation sur un écran
  /// assez large.
  static const maxNavigationTextScale = 1.3;

  /// Marge intérieure estimée de chaque destination, en pixels logiques.
  static const _destinationPadding = 12.0;

  /// Calcule le grossissement maximal (entre 1 et [maxNavigationTextScale])
  /// qui laisse tenir le plus long des [labels] sur une ligne.
  static double navigationTextScaleLimit(
    BuildContext context,
    List<String> labels,
  ) {
    final theme = Theme.of(context);
    // Mesure dans le style le plus large (gras), pour couvrir l'onglet
    // sélectionné.
    final style = (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
    );
    var longest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    if (longest == 0) return maxNavigationTextScale;
    final slot =
        MediaQuery.sizeOf(context).width / labels.length - _destinationPadding;
    return (slot / longest).clamp(1.0, maxNavigationTextScale);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _history = TabHistory();

  /// Vrai pendant un changement d'onglet provoqué par le bouton Retour,
  /// qui ne doit pas être ajouté à l'historique.
  bool _returning = false;

  /// Actif après un premier appui sur Retour depuis l'Accueil.
  Timer? _exitTimer;

  StatefulNavigationShell get shell => widget.shell;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = oldWidget.shell.currentIndex;
    final to = widget.shell.currentIndex;
    if (from == to) return;
    if (!_returning) _history.record(from, to);
    _returning = false;
    _cancelExit();
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _cancelExit() {
    _exitTimer?.cancel();
    _exitTimer = null;
  }

  /// Appelé quand Retour est pressé et qu'aucun écran ne peut être fermé
  /// dans l'onglet courant.
  void _handleBack() {
    final target = _history.back(shell.currentIndex);
    if (target != null) {
      _returning = true;
      shell.goBranch(target);
      return;
    }
    if (_exitTimer?.isActive ?? false) {
      _cancelExit();
      unawaited(SystemNavigator.pop());
      return;
    }
    _exitTimer = Timer(AppShell.exitConfirmationDelay, () {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).backAgainToExit),
          duration: AppShell.exitConfirmationDelay,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<Object?>(
      // L'application ne se ferme jamais au premier appui : le retour est
      // traité par _handleBack une fois l'onglet courant revenu à sa racine.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: shell,
        // Le contenu suit librement le grossissement du texte choisi dans
        // Android. Dans la barre de navigation seulement, il est plafonné pour
        // que le libellé le plus long tienne sur une ligne : sinon, sur les
        // petits écrans, les libellés se coupent au milieu des mots. Les
        // libellés restent lus en entier par TalkBack.
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppShell.navigationTextScaleLimit(
            context,
            _labels(l10n),
          ),
          child: _buildNavigationBar(l10n),
        ),
      ),
    );
  }

  List<String> _labels(AppLocalizations l10n) => [
    l10n.navHome,
    l10n.navHistory,
    l10n.navTips,
    l10n.navSettings,
  ];

  NavigationBar _buildNavigationBar(AppLocalizations l10n) {
    return NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: l10n.navHistory,
        ),
        NavigationDestination(
          icon: const Icon(Icons.lightbulb_outline),
          selectedIcon: const Icon(Icons.lightbulb),
          label: l10n.navTips,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.navSettings,
        ),
      ],
    );
  }
}
