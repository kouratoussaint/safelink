import 'package:safelink/features/share/shortcuts.dart';

/// Raccourcis simulés : tuile ([canRequest], réponse [answer]) et bulle
/// ([bubbleSupported], [bubblePermitted], [bubbleEnabled],
/// [bubbleDetectsCopies]) ; notifications ([notificationsAllowed], réponse
/// [notificationsAnswer]).
class FakeShortcuts implements ShortcutsPlatform {
  new({
    this.canRequest = false,
    this.answer = TileRequest.added,
    this.bubbleSupported = false,
    this.bubblePermitted = false,
    this.bubbleEnabled = false,
    this.bubbleDetectsCopies = false,
    this.notificationsAllowed = false,
    this.notificationsAnswer = true,
  });

  final bool canRequest;
  final TileRequest answer;
  bool bubbleSupported;
  bool bubblePermitted;
  bool bubbleEnabled;
  final bool bubbleDetectsCopies;
  bool notificationsAllowed;
  final bool notificationsAnswer;

  /// Nombre de demandes d'autorisation des notifications.
  int notificationRequests = 0;

  /// Nombre de demandes d'ajout de la tuile.
  int requests = 0;

  /// Nombre d'ouvertures du réglage « par-dessus d'autres applis ».
  int overlaySettingsOpened = 0;

  @override
  Future<bool> canRequestTile() async => canRequest;

  @override
  Future<TileRequest> requestTile() async {
    requests++;
    return answer;
  }

  BubbleState get _state => BubbleState(
    supported: bubbleSupported,
    permitted: bubblePermitted,
    enabled: bubbleEnabled && bubblePermitted,
    detectsCopies: bubbleDetectsCopies,
    notificationsAllowed: notificationsAllowed,
  );

  @override
  Future<BubbleState> bubbleState() async => _state;

  @override
  Future<bool> openOverlaySettings() async {
    overlaySettingsOpened++;
    return bubbleSupported;
  }

  @override
  Future<bool> requestNotifications() async {
    notificationRequests++;
    return notificationsAllowed = notificationsAllowed || notificationsAnswer;
  }

  @override
  Future<BubbleState> setBubble({required bool enabled}) async {
    if (!enabled || bubblePermitted) bubbleEnabled = enabled;
    return _state;
  }
}
