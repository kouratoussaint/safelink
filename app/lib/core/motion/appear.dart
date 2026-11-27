import 'package:material_ui/material_ui.dart';

/// Vrai si l'utilisateur a demandé de réduire les animations (réglage
/// d'accessibilité d'Android).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fait apparaître [child] en glissant vers le haut, avec un léger
/// décalage selon sa position [index] : les cartes arrivent l'une après
/// l'autre.
class Appear extends StatefulWidget {
  const new({required this.child, this.index = 0, super.key});

  final Widget child;

  /// Position dans la liste ; au-delà de 6, pas de décalage supplémentaire.
  final int index;

  /// Décalage entre deux éléments.
  static const step = Duration(milliseconds: 70);

  /// Durée de l'apparition d'un élément.
  static const duration = Duration(milliseconds: 320);

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = Appear.step * widget.index.clamp(0, 6);
    final total = delay + Appear.duration;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

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
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}
