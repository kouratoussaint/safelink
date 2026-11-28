import 'package:safelink/features/share/shortcuts.dart';

/// Raccourcis simulés : [canRequest] et la réponse [answer] à la demande
/// d'ajout de la tuile.
class FakeShortcuts implements ShortcutsPlatform {
  new({this.canRequest = false, this.answer = TileRequest.added});

  final bool canRequest;
  final TileRequest answer;

  /// Nombre de demandes d'ajout.
  int requests = 0;

  @override
  Future<bool> canRequestTile() async => canRequest;

  @override
  Future<TileRequest> requestTile() async {
    requests++;
    return answer;
  }
}
