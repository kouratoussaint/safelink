import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/share/shortcuts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(PlatformShortcuts.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('état de la bulle lu depuis Android', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'bubbleState' => {
          'supported': true,
          'permitted': true,
          'enabled': true,
          'detectsCopies': false,
          'notifications': true,
        },
        'requestNotifications' => false,
        _ => null,
      };
    });
    final shortcuts = PlatformShortcuts();
    expect(
      await shortcuts.bubbleState(),
      const BubbleState(
        supported: true,
        permitted: true,
        enabled: true,
        notificationsAllowed: true,
      ),
    );
    expect(await shortcuts.requestNotifications(), isFalse);
  });

  test('sans activité Android : rien de permis, aucune erreur', () async {
    final shortcuts = PlatformShortcuts();
    expect(await shortcuts.bubbleState(), const BubbleState());
    expect(await shortcuts.requestNotifications(), isFalse);
    expect(BubbleState.fromPlatform('autre chose'), const BubbleState());
  });
}
