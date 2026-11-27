import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/motion/appear.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Bouton « Écouter » : lit [text] à voix haute avec la voix du téléphone.
/// Un second appui arrête la lecture.
class ListenButton extends ConsumerStatefulWidget {
  const new({required this.text, this.background, this.foreground, super.key});

  /// Texte lu, en phrases courtes.
  final String text;

  /// Fond du bouton ; à défaut, la teinte secondaire du thème.
  final Color? background;

  /// Couleur du texte et du pictogramme.
  final Color? foreground;

  @override
  ConsumerState<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends ConsumerState<ListenButton> {
  bool _speaking = false;
  Speaker? _speaker;

  Future<void> _toggle() async {
    final speaker = ref.read(speakerProvider);
    _speaker = speaker;
    if (_speaking) {
      await speaker.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    final ok = await speaker.speak(widget.text);
    if (!mounted) return;
    setState(() => _speaking = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).listenUnavailable),
          ),
        );
    }
  }

  @override
  void dispose() {
    if (_speaking) unawaited(_speaker?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(150, 48),
        shape: const StadiumBorder(),
        backgroundColor: widget.background,
        foregroundColor: widget.foreground,
        textStyle: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: _toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _speaking
            ? const _SoundBars(key: ValueKey('bars'))
            : const Icon(Icons.volume_up_rounded, key: ValueKey('icon')),
      ),
      label: Text(_speaking ? l10n.listenStop : l10n.listen),
    );
  }
}

/// Trois barres qui bougent pendant la lecture.
class _SoundBars extends StatefulWidget {
  const new({super.key});

  @override
  State<_SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<_SoundBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && !_controller.isAnimating) {
      _controller.repeat().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return SizedBox.square(
      dimension: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height:
                    6 +
                    12 *
                        (0.5 +
                            0.5 *
                                math.sin(
                                  2 * math.pi * (_controller.value + i / 3),
                                )),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
