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

/// Raccourcis du système : tuile du volet des réglages rapides (ADR 0014).
abstract interface class ShortcutsPlatform {
  /// Le téléphone sait proposer l'ajout de la tuile (Android 13 et plus).
  Future<bool> canRequestTile();

  /// Propose d'ajouter la tuile au volet.
  Future<TileRequest> requestTile();
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

/// Le téléphone sait proposer l'ajout de la tuile.
final canRequestTileProvider = FutureProvider<bool>(
  (ref) => ref.watch(shortcutsProvider).canRequestTile(),
  retry: (_, _) => null,
);
