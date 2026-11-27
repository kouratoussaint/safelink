import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/app/router.dart';
import 'package:safelink/app/routes.dart';
import 'package:safelink/features/results/result_views.dart';
import 'package:safelink/features/share/shared_content.dart';

import '../helpers/fake_share.dart';
import '../helpers/fake_speaker.dart';
import '../helpers/pump_app.dart';
import 'analysis_flow_test.dart' as flow;

/// Message avec deux liens différents.
const twoLinks =
    'Votre colis est bloqué. Payez les frais ici https://colis-bf.top/payer '
    'ou suivez-le sur www.suivi.exemple.org/colis avant ce soir.';

const question = 'Que voulez-vous vérifier ?';

/// Ouvre l'écran de partage pour [content], comme après un partage.
Future<void> openShare(WidgetTester tester, SharedContent content) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(routerProvider)
      .go(AppRoutes.share, extra: planShare(content));
  await tester.pumpAndSettle();
}

/// Écrans du partage : choix, choix du lien, refus.
Future<void> visitShareScreens(WidgetTester tester) async {
  await openShare(tester, const SharedText(twoLinks, filesIgnored: true));
  expect(tester.takeException(), isNull, reason: 'choix');
  await flow.scrollTo(tester, find.text('Le lien seulement'));
  await tester.tap(find.text('Le lien seulement'));
  await tester.pumpAndSettle();
  await flow.scrollTo(
    tester,
    find.descendant(
      of: find.byType(HighlightedUrl),
      matching: find.textContaining('exemple.org'),
    ),
  );
  expect(tester.takeException(), isNull, reason: 'choix du lien');
  for (final content in [
    const SharedFiles(SharedFileKind.image),
    const SharedFiles(SharedFileKind.video),
    const SharedFiles(SharedFileKind.other),
    const SharedNothing(),
  ]) {
    await openShare(tester, content);
    await flow.scrollTo(tester, find.text('Aller à l’accueil'));
    expect(tester.takeException(), isNull, reason: '$content');
  }
}

NavigationBar navigationBar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  group('partage à froid', () {
    testWidgets('un lien seul est analysé tout de suite', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedText('https://example.com')]),
      );
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.text('Analyse insuffisante'), findsOneWidget);
      // SafeLink n'ouvre jamais le lien partagé.
      expect(find.widgetWithText(ButtonStyleButton, 'Ouvrir'), findsNothing);

      await flow.pressBack(tester);
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });

    testWidgets('un texte sans lien est analysé tout de suite', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([
          const SharedText(
            'Envoyez votre code secret Orange Money au 70 00 00 00 '
            'pour recevoir votre gain.',
          ),
        ]),
      );
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.textContaining('Synthèse'), findsOneWidget);
    });

    testWidgets('texte et lien : « Tout le message »', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedText(flow.scamMessage)]),
      );
      expect(appBarTitle('Partage reçu'), findsOneWidget);
      expect(find.text(question), findsOneWidget);
      // Le texte reçu est montré.
      expect(
        find.textContaining('Vous avez gagné 500 000 FCFA'),
        findsOneWidget,
      );
      expect(find.text('Le texte et son lien'), findsOneWidget);
      // Le domaine du lien, forme déguisée rétablie.
      expect(find.text('orange-gain.xyz'), findsOneWidget);

      await flow.scrollTo(tester, find.text('Tout le message'));
      await tester.tap(find.text('Tout le message'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.text('Synthèse : Danger'), findsOneWidget);

      // L'écran de partage est remplacé : Retour ramène à l'accueil.
      await flow.pressBack(tester);
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });

    testWidgets('texte et lien : « Le lien seulement »', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedText(flow.scamMessage)]),
      );
      await flow.scrollTo(tester, find.text('Le lien seulement'));
      await tester.tap(find.text('Le lien seulement'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.text('Lien suspect'), findsOneWidget);
    });

    testWidgets('plusieurs liens : l’utilisateur choisit lequel', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedText(twoLinks)]),
      );
      expect(find.text('Le texte et ses 2 liens'), findsOneWidget);
      expect(find.text('2 liens : choisissez-en un'), findsOneWidget);
      expect(find.text('Quel lien vérifier ?'), findsNothing);

      await flow.scrollTo(tester, find.text('Le lien seulement'));
      await tester.tap(find.text('Le lien seulement'));
      await tester.pumpAndSettle();
      expect(find.text('Quel lien vérifier ?'), findsOneWidget);
      final second = find.descendant(
        of: find.byType(HighlightedUrl),
        matching: find.textContaining('suivi.exemple.org'),
      );
      await flow.scrollTo(tester, second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.textContaining('suivi.exemple.org'), findsWidgets);
      expect(find.textContaining('colis-bf.top'), findsNothing);
    });

    testWidgets('« Écouter » lit la question et les choix', (tester) async {
      final speaker = FakeSpeaker();
      await pumpSafeLinkApp(
        tester,
        speaker: speaker,
        shareSource: FakeShareSource([const SharedText(twoLinks)]),
      );
      await tester.tap(find.text('Écouter'));
      await tester.pumpAndSettle();
      expect(speaker.spoken.single, contains(question));
      expect(speaker.spoken.single, contains('Tout le message'));
      expect(speaker.spoken.single, contains('le lien seulement'));
    });

    testWidgets('Retour depuis le choix ramène à l’accueil', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedText(twoLinks)]),
      );
      await flow.pressBack(tester);
      expect(find.text('Lien à vérifier'), findsOneWidget);
      expect(appBarTitle('Partage reçu'), findsNothing);
    });

    testWidgets('reçu avant la présentation : ouvert juste après', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        onboarded: false,
        online: null,
        shareSource: FakeShareSource([const SharedText(twoLinks)]),
      );
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(appBarTitle('Partage reçu'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Partage reçu'), findsOneWidget);
    });
  });

  group('partage à chaud', () {
    testWidgets('reçu depuis un autre onglet : ouvert dans l’Accueil', (
      tester,
    ) async {
      final source = FakeShareSource();
      await pumpSafeLinkApp(tester, shareSource: source);
      await tapDestination(tester, 'Paramètres');
      expect(navigationBar(tester).selectedIndex, 3);

      source.send(const SharedText('https://example.com'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(navigationBar(tester).selectedIndex, 0);
      expect(source.listens, 1);
    });

    testWidgets('un nouveau partage remplace le précédent', (tester) async {
      final source = FakeShareSource([const SharedText(twoLinks)]);
      await pumpSafeLinkApp(tester, shareSource: source);
      expect(find.text('Le texte et ses 2 liens'), findsOneWidget);

      source.send(const SharedText(flow.scamMessage));
      await tester.pumpAndSettle();
      expect(find.text('Le texte et son lien'), findsOneWidget);
      await flow.pressBack(tester);
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });
  });

  group('refus expliqués', () {
    testWidgets('photo : pas encore, avec quoi faire à la place', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedFiles(SharedFileKind.image)]),
      );
      expect(find.text('Pas encore possible'), findsOneWidget);
      expect(
        find.text('SafeLink ne vérifie pas encore les photos.'),
        findsOneWidget,
      );
      await flow.scrollTo(tester, find.text('Aller à l’accueil'));
      expect(find.textContaining('copiez-le, puis collez-le'), findsOneWidget);
      await tester.tap(find.text('Aller à l’accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });

    testWidgets('fichier : pas encore', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedFiles(SharedFileKind.other)]),
      );
      expect(
        find.text('SafeLink ne vérifie pas encore les fichiers.'),
        findsOneWidget,
      );
    });

    testWidgets('partage vide : rien à vérifier', (tester) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([const SharedNothing()]),
      );
      expect(find.text('Rien à vérifier'), findsOneWidget);
      expect(find.text('Le partage ne contenait aucun texte.'), findsOneWidget);
    });

    testWidgets('fichier joint à un texte : seul le texte est vérifié', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([
          const SharedText('https://example.com', filesIgnored: true),
        ]),
      );
      expect(find.text(question), findsOneWidget);
      expect(find.text('Fichier joint'), findsOneWidget);
      expect(
        find.text('Le fichier n’est pas ouvert : seul le texte est vérifié.'),
        findsOneWidget,
      );
    });

    testWidgets('texte coupé : seul le début du message est vérifié', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        shareSource: FakeShareSource([
          const SharedText('Bonjour, voici la suite', truncated: true),
        ]),
      );
      expect(find.text('Message très long'), findsOneWidget);
      expect(find.text('Le lien seulement'), findsNothing);
      await flow.scrollTo(tester, find.text('Tout le message'));
      await tester.tap(find.text('Tout le message'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
    });
  });

  testWidgets('l’aide et l’accueil expliquent comment partager', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester);
    await flow.scrollTo(tester, find.text('Plus rapide : partager'));
    expect(find.textContaining('« Vérifier avec SafeLink »'), findsOneWidget);
    expect(find.textContaining('partager un texte'), findsNothing);

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go(AppRoutes.help);
    await tester.pumpAndSettle();
    await flow.scrollTo(tester, find.text('Plus rapide : partager'));
    expect(
      find.text('Appuyez longtemps sur le message ou le lien reçu'),
      findsOneWidget,
    );
  });
}
