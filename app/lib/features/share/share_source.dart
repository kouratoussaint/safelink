import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/features/share/shared_content.dart';

/// Source des partages reçus d'autres applications ; remplacée par une
/// source simulée dans les tests.
abstract interface class ShareSource {
  /// Partages reçus : celui qui a lancé l'application d'abord, puis ceux
  /// qui arrivent pendant qu'elle est ouverte.
  Stream<SharedContent> shares();
}

/// Partages transmis par `MainActivity` sur le canal
/// `com.fasosoft.safelink/share` (ADR 0004).
///
/// L'activité garde le partage jusqu'à ce qu'il soit pris (`take`) et
/// prévient (`available`) quand un nouveau arrive : aucun partage n'est
/// perdu, même reçu pendant la présentation de première ouverture.
final class PlatformShareSource implements ShareSource {
  /// Crée la source ; [channel] remplace le canal dans les tests.
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(name);

  /// Nom du canal.
  static const name = 'com.fasosoft.safelink/share';

  final MethodChannel _channel;

  @override
  Stream<SharedContent> shares() {
    late final StreamController<SharedContent> controller;

    Future<void> take() async {
      Object? raw;
      try {
        raw = await _channel.invokeMethod<Object?>('take');
      } on PlatformException {
        return;
      } on MissingPluginException {
        // Pas d'activité Android (tests, autre plateforme).
        return;
      }
      final content = SharedContent.fromPlatform(raw);
      if (content != null && !controller.isClosed) controller.add(content);
    }

    controller = StreamController<SharedContent>(
      onListen: () {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'available') await take();
          return null;
        });
        unawaited(take());
      },
      onCancel: () {
        _channel.setMethodCallHandler(null);
        return controller.close();
      },
    );
    return controller.stream;
  }
}

/// Source des partages ; remplacée dans les tests.
final shareSourceProvider = Provider<ShareSource>(
  (ref) => PlatformShareSource(),
);

/// Dernier partage reçu et pas encore ouvert.
///
/// Écouté par l'écran principal, qui ouvre le partage puis le retire avec
/// [ShareInbox.take]. Tant que la présentation de première ouverture n'est
/// pas terminée, le partage attend ici.
final shareInboxProvider = NotifierProvider<ShareInbox, SharedContent?>(
  ShareInbox.new,
);

/// Boîte de réception des partages.
class ShareInbox extends Notifier<SharedContent?> {
  @override
  SharedContent? build() {
    final subscription = ref
        .watch(shareSourceProvider)
        .shares()
        .listen((content) => state = content);
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// Retire et renvoie le partage en attente.
  SharedContent? take() {
    final content = state;
    state = null;
    return content;
  }
}
