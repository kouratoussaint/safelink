import 'dart:async';

import 'package:safelink/core/speech/speaker.dart';

/// Lecteur à voix haute simulé : garde les textes lus. Si [gate] est
/// fourni, la lecture dure jusqu'à ce qu'il soit complété.
final class FakeSpeaker implements Speaker {
  new({this.available = true});

  /// Faux : le téléphone n'a pas de voix française.
  final bool available;

  final List<String> spoken = [];
  int stops = 0;
  Completer<void>? gate;

  @override
  Future<bool> speak(String text) async {
    if (!available) return false;
    spoken.add(text);
    await gate?.future;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    final pending = gate;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}
