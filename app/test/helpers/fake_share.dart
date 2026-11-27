import 'dart:async';

import 'package:safelink/features/share/share_source.dart';
import 'package:safelink/features/share/shared_content.dart';

/// Partages simulés : `initial` comme reçus au lancement, puis [send] pour
/// un partage reçu pendant que l'application est ouverte.
class FakeShareSource implements ShareSource {
  new([List<SharedContent> initial = const []]) {
    initial.forEach(_controller.add);
  }

  final _controller = StreamController<SharedContent>();

  /// Nombre d'abonnements : un seul est attendu.
  int listens = 0;

  @override
  Stream<SharedContent> shares() {
    listens++;
    return _controller.stream;
  }

  /// Simule un partage reçu à chaud.
  void send(SharedContent content) => _controller.add(content);
}
