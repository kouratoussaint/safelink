import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/online/online_controller.dart';
import 'package:safelink/features/results/link_identity_view.dart';
import 'package:safelink/features/results/message_contents.dart';
import 'package:safelink/features/share/shared_content.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

import '../helpers/fake_speaker.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_quick.dart';
import 'analysis_flow_test.dart' as flow;
import 'online_flow_test.dart' show cleanChecker;

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));
  final context = AnalysisContext(clock: () => DateTime.utc(2026, 11, 28));

  IdentityText describe(String link) =>
      IdentityText.of(l10n, UrlAnalyzer().analyze(link, context).identity!);

  group('ce qu’est un lien, en mots simples', () {
    test('fichier Google Drive : déposé par une personne, non vérifié', () {
      final text = describe('https://drive.google.com/file/d/1Ab/view');
      expect(text.title, 'Fichier Google Drive');
      expect(
        text.sentence,
        'Ce lien ouvre un fichier déposé par une personne sur Google Drive.',
      );
      expect(
        text.note,
        'Google Drive ne vérifie pas ce que la personne y a mis.',
      );
      expect(text.spoken, '${text.sentence} ${text.note}');
    });

    test('WhatsApp : le numéro est dit lisiblement', () {
      final text = describe('https://wa.me/22670123456?text=Bonjour');
      expect(text.title, 'Discussion WhatsApp');
      // Masqué au milieu, comme partout ; non épelé à l'oral.
      expect(
        text.sentence,
        'Ce lien ouvre une discussion WhatsApp avec le +226 70 •• •• 56.',
      );
      expect(
        text.spoken,
        startsWith(
          'Ce lien ouvre une discussion WhatsApp '
          'avec un numéro de téléphone.',
        ),
      );
      expect(text.note, contains('déjà écrit'));
      expect(
        describe('https://wa.me/message/AB12').sentence,
        'Ce lien ouvre une discussion WhatsApp avec une personne ou une '
        'entreprise.',
      );
      expect(
        describe('https://m.me/promo').sentence,
        'Ce lien ouvre une discussion Messenger avec «\u00a0promo\u00a0».',
      );
    });

    test('formulaire : jamais de codes', () {
      final text = describe('https://forms.gle/AbCd');
      expect(text.title, 'Formulaire Google Forms');
      expect(text.note, contains('jamais vos codes'));
    });

    test('application : magasin, ou fichier à installer', () {
      expect(
        describe(
          'https://play.google.com/store/apps/details?id=com.exemple.app',
        ).sentence,
        'Ce lien ouvre, sur Google Play, la page de l’application '
        '«\u00a0com.exemple.app\u00a0».',
      );
      final apk = describe('http://promo-bf.top/bonus.apk');
      expect(apk.title, 'Application à installer');
      expect(apk.sentence, contains('(.apk)'));
      expect(apk.note, contains('vos codes'));
      expect(identityWarns(LinkKind.appFile), isTrue);
    });

    test('fichiers : mise en garde selon le type', () {
      expect(describe('https://exemple.com/a.exe').title, 'Fichier EXE');
      expect(describe('https://exemple.com/a.exe').note, contains('programme'));
      expect(describe('https://exemple.com/a.zip').note, contains('archive'));
      expect(describe('https://exemple.com/a.pdf').note, isNull);
      expect(
        describe('https://www.mediafire.com/file/x/a.pdf').sentence,
        'Ce lien télécharge un fichier PDF depuis MediaFire.',
      );
    });

    test('marques : site officiel avec sa limite, imitation', () {
      final official = describe('https://www.orange.bf/');
      expect(official.title, 'Site officiel de Orange');
      expect(
        official.note,
        'Même sur un vrai site, ne donnez jamais vos codes.',
      );
      final imitation = describe('http://orange-gain.xyz/retrait');
      expect(imitation.title, 'Imitation de Orange');
      expect(
        imitation.sentence,
        'Ce site n’appartient pas à Orange, mais son nom y ressemble.',
      );
      expect(identityWarns(LinkKind.imitation), isTrue);
      expect(identityWarns(LinkKind.website), isFalse);
    });

    test('chaque nature a un titre, une phrase et un pictogramme', () {
      for (final kind in LinkKind.values) {
        final text = IdentityText.of(
          l10n,
          LinkIdentity(kind, service: 'Service', detail: 'pdf'),
        );
        expect(text.title.trim(), isNotEmpty, reason: kind.name);
        expect(text.sentence, endsWith('.'), reason: kind.name);
        expect(identityIcon(kind), isA<IconData>());
      }
    });

    test('numéros : début et fin seulement', () {
      expect(formatPhone('+22670123456'), '+226 70 •• •• 56');
      expect(formatPhone('+2250701020304'), '+2250•••04');
      expect(formatPhone('+123456'), '+123456');
    });
  });

  group('contenu d’un message', () {
    test('liens, numéros, codes, sommes', () {
      final extraction = MessageAnalyzer()
          .analyze(
            'Gagnez 500 000 FCFA ! Appelez le 70 00 00 00 ou composez '
            '*144*2*1# puis payez 1 000 FCFA sur https://exemple.com',
            context,
          )
          .extraction!;
      expect(messageContents(l10n, extraction).map((c) => c.$2), [
        '1 lien',
        '1 numéro de téléphone',
        '1 code à composer',
        '2 sommes d’argent, jusqu’à 500 000 FCFA',
      ]);
    });

    test('sommes : chiffres groupés par trois', () {
      expect(formatAmount(500), '500 FCFA');
      expect(formatAmount(25000), '25 000 FCFA');
      expect(formatAmount(1500000), '1 500 000 FCFA');
    });
  });

  group('écran de résultat', () {
    testWidgets('lien : nature et vérifications, sous le verdict', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(tester);
      await flow.enterText(tester, 'http://orange-gain.xyz/retrait');
      await flow.analyze(tester, 'Analyser le lien');

      expect(find.text('Sur le téléphone'), findsOneWidget);
      // Vérification en ligne désactivée dans ces tests.
      expect(find.text('En ligne : désactivée'), findsOneWidget);
      expect(find.text('Imitation de Orange'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Vérifié sur le téléphone\u00a0; vérification en ligne désactivée.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('vérifié en ligne : « En ligne » coché', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: cleanChecker(),
      );
      await flow.enterText(tester, 'https://lefaso.net/');
      await flow.analyze(tester, 'Analyser le lien');

      expect(find.text('En ligne'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Vérifié sur le téléphone et en ligne.'),
        findsOneWidget,
      );
      expect(find.text('Site web'), findsOneWidget);
      expect(find.text('Ce lien mène au site lefaso.net.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('message : ce qu’il contient', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSafeLinkApp(tester);
      await flow.selectMessageMode(tester);
      await flow.enterText(tester, flow.scamMessage);
      await flow.analyze(tester, 'Analyser le message');

      await flow.scrollTo(tester, find.text('Dans ce message'));
      expect(
        find.bySemanticsLabel(RegExp('^Dans ce message.*1 lien')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('« Écouter » dit aussi ce qu’est le lien', (tester) async {
      final speaker = FakeSpeaker();
      await pumpSafeLinkApp(tester, speaker: speaker);
      await flow.enterText(tester, 'https://chat.whatsapp.com/AbCd123');
      await flow.analyze(tester, 'Analyser le lien');
      await tester.tap(find.text('Écouter'));
      await tester.pumpAndSettle();
      expect(
        speaker.spoken.single,
        contains('Ce lien vous fait entrer dans un groupe WhatsApp.'),
      );
    });

    testWidgets('pendant l’analyse d’un lien, l’étape « En ligne » est '
        'annoncée', (tester) async {
      await pumpSafeLinkApp(
        tester,
        online: OnlineChoice.enabled,
        onlineChecker: cleanChecker(),
      );
      await flow.enterText(tester, 'https://lefaso.net/');
      await tester.tap(find.text('Analyser le lien'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Sur le téléphone'), findsOneWidget);
      expect(find.text('En ligne'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('panneau rapide : nature du lien et vérifications', (
    tester,
  ) async {
    await pumpQuickPanel(
      tester,
      copied: const SharedText(
        'https://drive.google.com/file/d/1Ab/view',
        origin: ShareOrigin.clipboard,
      ),
    );
    expect(find.text('Fichier Google Drive'), findsOneWidget);
    expect(find.text('Sur le téléphone'), findsOneWidget);
  });
}
