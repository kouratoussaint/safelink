import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Réponse à la demande d'ajout de la tuile au volet.
enum TileRequest {
  /// Ajoutée.
  added,

  /// Déjà présente.
  already,

  /// L'utilisateur a refusé.
  refused,

  /// Demande impossible sur ce téléphone (avant Android 13).
  unsupported;

  static TileRequest parse(Object? raw) => switch (raw) {
    'added' => added,
    'already' => already,
    'refused' => refused,
    _ => unsupported,
  };
}

/// État de la bulle flottante (ADR 0014).
@immutable
final class BubbleState {
  const new({
    this.supported = false,
    this.permitted = false,
    this.enabled = false,
    this.detectsCopies = false,
  });

  /// Lit l'état envoyé par Android.
  factory fromPlatform(Object? raw) => raw is Map
      ? BubbleState(
          supported: raw['supported'] == true,
          permitted: raw['permitted'] == true,
          enabled: raw['enabled'] == true,
          detectsCopies: raw['detectsCopies'] == true,
        )
      : const BubbleState();

  /// Le téléphone permet la bulle (Android 8+, pas Android Go récent).
  final bool supported;

  /// L'autorisation « Afficher par-dessus d'autres applis » est donnée.
  final bool permitted;

  /// La bulle est choisie et active.
  final bool enabled;

  /// Android prévient d'une copie (Android 9 et avant) : la bulle se cache
  /// et revient à la copie. Sinon, elle se range au bord de l'écran
  /// (ADR 0015).
  final bool detectsCopies;

  @override
  bool operator ==(Object other) =>
      other is BubbleState &&
      other.supported == supported &&
      other.permitted == permitted &&
      other.enabled == enabled &&
      other.detectsCopies == detectsCopies;

  @override
  int get hashCode => Object.hash(supported, permitted, enabled, detectsCopies);
}

/// Raccourcis du système : tuile du volet des réglages rapides et bulle
/// flottante (ADR 0014).
abstract interface class ShortcutsPlatform {
  /// Le téléphone sait proposer l'ajout de la tuile (Android 13 et plus).
  Future<bool> canRequestTile();

  /// Propose d'ajouter la tuile au volet.
  Future<TileRequest> requestTile();

  /// État de la bulle.
  Future<BubbleState> bubbleState();

  /// Ouvre le réglage Android « Afficher par-dessus d'autres applis » ;
  /// `false` s'il n'a pas pu s'ouvrir.
  Future<bool> openOverlaySettings();

  /// Active ou désactive la bulle ; l'activation n'a lieu que si
  /// l'autorisation est donnée.
  Future<BubbleState> setBubble({required bool enabled});
}

/// Raccourcis servis par `MainActivity` sur le canal
/// `com.fasosoft.safelink/shortcuts`.
final class PlatformShortcuts implements ShortcutsPlatform {
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(name);

  /// Nom du canal.
  static const name = 'com.fasosoft.safelink/shortcuts';

  final MethodChannel _channel;

  @override
  Future<bool> canRequestTile() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestTile') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<BubbleState> bubbleState() async {
    try {
      return BubbleState.fromPlatform(
        await _channel.invokeMethod<Object?>('bubbleState'),
      );
    } on PlatformException {
      return const BubbleState();
    } on MissingPluginException {
      return const BubbleState();
    }
  }

  @override
  Future<bool> openOverlaySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openOverlaySettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<BubbleState> setBubble({required bool enabled}) async {
    try {
      return BubbleState.fromPlatform(
        await _channel.invokeMethod<Object?>('setBubble', {'enabled': enabled}),
      );
    } on PlatformException {
      return const BubbleState();
    } on MissingPluginException {
      return const BubbleState();
    }
  }

  @override
  Future<TileRequest> requestTile() async {
    try {
      return TileRequest.parse(
        await _channel.invokeMethod<String>('requestTile'),
      );
    } on PlatformException {
      return TileRequest.unsupported;
    } on MissingPluginException {
      return TileRequest.unsupported;
    }
  }
}

/// Raccourcis du système ; remplacés dans les tests.
final shortcutsProvider = Provider<ShortcutsPlatform>(
  (ref) => PlatformShortcuts(),
);

/// État de la bulle flottante, relu au retour dans SafeLink.
final bubbleStateProvider = FutureProvider<BubbleState>(
  (ref) => ref.watch(shortcutsProvider).bubbleState(),
  retry: (_, _) => null,
);

/// Le téléphone sait proposer l'ajout de la tuile.
final canRequestTileProvider = FutureProvider<bool>(
  (ref) => ref.watch(shortcutsProvider).canRequestTile(),
  retry: (_, _) => null,
);
