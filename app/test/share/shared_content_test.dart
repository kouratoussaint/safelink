import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/share/share_source.dart';
import 'package:safelink/features/share/shared_content.dart';

AnalysisRequest analyzed(SharePlan plan) => (plan as AnalyzeShared).request;

ChooseShared chosen(SharePlan plan) => plan as ChooseShared;

void main() {
  group('lecture du partage envoyé par Android', () {
    test('ce qui n’est pas un partage est ignoré', () {
      expect(SharedContent.fromPlatform(null), isNull);
      expect(SharedContent.fromPlatform('texte'), isNull);
    });

    test('texte, texte coupé, fichier joint', () {
      expect(
        SharedContent.fromPlatform({'type': 'text/plain', 'text': 'Bonjour'}),
        const SharedText('Bonjour'),
      );
      expect(
        SharedContent.fromPlatform({
          'text': 'Bonjour',
          'truncated': true,
          'files': true,
        }),
        const SharedText('Bonjour', truncated: true, filesIgnored: true),
      );
    });

    test('fichiers seuls : nature tirée du type', () {
      expect(
        SharedContent.fromPlatform({'type': 'image/jpeg', 'files': true}),
        const SharedFiles(SharedFileKind.image),
      );
      expect(
        SharedContent.fromPlatform({'type': 'video/mp4', 'files': true}),
        const SharedFiles(SharedFileKind.video),
      );
      expect(
        SharedContent.fromPlatform({'type': 'text/plain', 'files': true}),
        const SharedFiles(SharedFileKind.other),
      );
      expect(
        SharedContent.fromPlatform({'files': true}),
        const SharedFiles(SharedFileKind.other),
      );
    });

    test('origine : partage, sélection, texte copié', () {
      expect(
        SharedContent.fromPlatform({'source': 'selection', 'text': 'Bonjour'}),
        const SharedText('Bonjour', origin: ShareOrigin.selection),
      );
      expect(
        SharedContent.fromPlatform({'source': 'clipboard', 'text': 'Bonjour'}),
        const SharedText('Bonjour', origin: ShareOrigin.clipboard),
      );
      expect(
        SharedContent.fromPlatform({'source': 'inconnu', 'text': 'Bonjour'}),
        const SharedText('Bonjour'),
      );
      // Rien de copié.
      expect(
        SharedContent.fromPlatform({'source': 'clipboard', 'text': null}),
        const SharedNothing(origin: ShareOrigin.clipboard),
      );
      // Texte copié marqué secret : jamais lu, même s'il est présent.
      expect(
        SharedContent.fromPlatform({
          'source': 'clipboard',
          'sensitive': true,
          'text': '1234',
        }),
        const SharedNothing(origin: ShareOrigin.clipboard, sensitive: true),
      );
    });

    test('un lien copié seul est analysé tout de suite', () {
      final request = analyzed(
        planShare(
          const SharedText(
            'https://exemple.com/page',
            origin: ShareOrigin.clipboard,
          ),
        ),
      );
      expect(request.kind, AnalysisKind.link);
    });

    test('vide ou illisible', () {
      expect(
        SharedContent.fromPlatform({'text': '   '}),
        const SharedNothing(),
      );
      expect(SharedContent.fromPlatform({'text': null}), const SharedNothing());
      expect(
        SharedContent.fromPlatform({'unreadable': true, 'text': 'x'}),
        const SharedNothing(),
      );
    });

    test('le texte n’apparaît jamais dans les journaux', () {
      const content = SharedText('mon code secret 1234');
      expect(content.toString(), isNot(contains('secret')));
      final plan = chosen(
        planShare(const SharedText('Voir https://exemple.com/a et la suite')),
      );
      expect(plan.links.single.toString(), isNot(contains('exemple')));
    });
  });

  group('que faire du partage', () {
    test('un lien seul est analysé tout de suite comme un lien', () {
      for (final text in [
        'https://exemple.com/page',
        '  https://exemple.com/page \n',
        '<https://exemple.com/page>.',
      ]) {
        final request = analyzed(planShare(SharedText(text)));
        expect(request.kind, AnalysisKind.link, reason: text);
        expect(request.text, 'https://exemple.com/page', reason: text);
      }
    });

    test('un lien déguisé seul est rétabli', () {
      final request = analyzed(
        planShare(const SharedText('hxxp://orange-gain[.]xyz/retrait')),
      );
      expect(request.kind, AnalysisKind.link);
      expect(request.text, 'http://orange-gain.xyz/retrait');
    });

    test('un texte sans lien est analysé tout de suite comme un message', () {
      const text = 'Envoyez votre code secret au 70 00 00 00 avant ce soir.';
      final request = analyzed(planShare(const SharedText(text)));
      expect(request.kind, AnalysisKind.message);
      expect(request.text, text);
    });

    test('texte et lien : choix proposé', () {
      final plan = chosen(
        planShare(
          const SharedText(
            'Bravo, vous avez gagné ! Réclamez ici : '
            'http://orange-money-bf.secure-login.xyz/verify',
          ),
        ),
      );
      expect(plan.long, isFalse);
      expect(plan.links, hasLength(1));
      final link = plan.links.single;
      expect(link.url, 'http://orange-money-bf.secure-login.xyz/verify');
      // Le domaine réellement enregistré, pas le début trompeur.
      expect(link.domain, 'secure-login.xyz');
      expect(plan.messageText, plan.content.text);
    });

    test('plusieurs liens : dans l’ordre, sans doublon, masqués', () {
      final plan = chosen(
        planShare(
          const SharedText(
            'Lien 1 : https://un.exemple.com/a?token=abcdefghijklmnopqrstuvwxyz123456 '
            'lien 2 : www.deux.exemple.org et encore '
            'https://un.exemple.com/a?token=abcdefghijklmnopqrstuvwxyz123456',
          ),
        ),
      );
      expect(plan.links, hasLength(2));
      expect(plan.links.first.domain, 'exemple.com');
      expect(plan.links.last.domain, 'exemple.org');
      expect(plan.links.first.displayed, isNot(contains('abcdefghijklmnop')));
    });

    test('le même lien répété : choix proposé, un seul lien', () {
      final plan = chosen(
        planShare(const SharedText('https://exemple.com https://exemple.com')),
      );
      expect(plan.links, hasLength(1));
    });

    test('texte coupé ou trop long : choix, début seulement', () {
      final cut = chosen(
        planShare(const SharedText('Bonjour', truncated: true)),
      );
      expect(cut.long, isTrue);
      expect(cut.links, isEmpty);

      final long = chosen(
        planShare(
          SharedText('${'é' * 30} https://exemple.com'),
          maxMessageLength: 20,
        ),
      );
      expect(long.long, isTrue);
      expect(long.messageText, 'é' * 20);
      // Les liens de tout le texte restent proposés.
      expect(long.links.single.url, 'https://exemple.com');
    });

    test('fichier joint au texte : choix, avec l’avertissement', () {
      final plan = chosen(
        planShare(const SharedText('https://exemple.com', filesIgnored: true)),
      );
      expect(plan.content.filesIgnored, isTrue);
      expect(plan.links, hasLength(1));
    });

    test('fichiers seuls ou partage vide : refus expliqué', () {
      expect(
        planShare(const SharedFiles(SharedFileKind.image)),
        isA<RefuseShared>(),
      );
      expect(planShare(const SharedNothing()), isA<RefuseShared>());
    });
  });

  group('canal Android', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(PlatformShareSource.name);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('prend le partage du lancement, puis ceux annoncés', () async {
      final queue = <Object?>[
        {'type': 'text/plain', 'text': 'Premier'},
        null,
        {'type': 'text/plain', 'text': 'Second'},
      ];
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return queue.isEmpty ? null : queue.removeAt(0);
      });
      final received = <SharedContent>[];
      final subscription = PlatformShareSource().shares().listen(received.add);
      await pumpEventQueue();
      expect(received, [const SharedText('Premier')]);

      Future<void> announce() async {
        await messenger.handlePlatformMessage(
          PlatformShareSource.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('available'),
          ),
          (_) {},
        );
        await pumpEventQueue();
      }

      // Annonce sans partage (déjà pris) : rien.
      await announce();
      await announce();
      expect(received, [
        const SharedText('Premier'),
        const SharedText('Second'),
      ]);
      expect(calls, ['take', 'take', 'take']);
      await subscription.cancel();
    });

    test('sans activité Android : aucun partage, aucune erreur', () async {
      final received = <SharedContent>[];
      final subscription = PlatformShareSource().shares().listen(received.add);
      await pumpEventQueue();
      expect(received, isEmpty);
      await subscription.cancel();
    });
  });
}
