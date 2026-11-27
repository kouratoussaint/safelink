import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_screen.dart';
import 'package:safelink/features/analysis/analysis_service.dart';

import '../helpers/pump_app.dart';

const scamMessage =
    'Félicitations ! Vous avez gagné 500 000 FCFA. Pour recevoir votre gain, '
    'envoyez votre code secret Orange Money au 70 00 00 00 et cliquez sur '
    'hxxp://orange-gain[.]xyz/retrait avant ce soir.';

/// Presse-papiers simulé : enregistre chaque lecture et chaque écriture.
class FakeClipboard {
  new(this.content);

  String? content;
  int reads = 0;
  final writes = <String>[];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            reads++;
            return content == null ? null : {'text': content};
          case 'Clipboard.setData':
            final text = (call.arguments as Map)['text'] as String;
            writes.add(text);
            content = text;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }
}

/// Service qui attend qu'on le libère, ou échoue au premier appel.
class ControlledService implements AnalysisService {
  new({this.failFirst = false});

  final bool failFirst;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<AnalysisOutcome> analyze(
    AnalysisRequest request, {
    bool online = false,
    void Function(AnalysisStage stage)? onStage,
  }) async {
    calls++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (failFirst && calls == 1) throw StateError('échec simulé');
    return DeviceAnalysisService.analyzeNow(request.kind, request.text);
  }
}

Finder button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<ButtonStyleButton>(),
);

/// Fait défiler l'accueil d'un cran, depuis la marge gauche pour ne pas
/// faire défiler le champ de texte à la place de la page.
Future<void> scrollHome(WidgetTester tester, Finder list) async {
  final origin = tester.getTopLeft(list) + const Offset(6, 120);
  await tester.dragFrom(origin, const Offset(0, -150));
  await tester.pumpAndSettle();
}

Future<void> enterText(WidgetTester tester, String text) async {
  // Le champ peut être hors de l'écran (texte agrandi, analyse précédente) :
  // retour en haut de l'accueil, puis défilement jusqu'au champ.
  final list = find.byType(Scrollable).first;
  await tester.fling(list, const Offset(0, 2000), 3000);
  await tester.pumpAndSettle();
  for (var i = 0; i < 20 && find.byType(TextField).evaluate().isEmpty; i++) {
    await scrollHome(tester, list);
  }
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// Choisit le mode « Message » sur l'accueil.
Future<void> selectMessageMode(WidgetTester tester) async {
  await tester.fling(
    find.byType(Scrollable).first,
    const Offset(0, 2000),
    3000,
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Message'),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Message'));
  await tester.pumpAndSettle();
}

Future<void> analyze(WidgetTester tester, String label) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 20 && button(label).evaluate().isEmpty; i++) {
    await scrollHome(tester, list);
  }
  await tester.ensureVisible(button(label));
  await tester.pumpAndSettle();
  await tester.tap(button(label));
  await tester.pumpAndSettle();
}

/// Bouton Retour d'Android.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Fait défiler jusqu'à [finder], entièrement visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('accueil', () {
    testWidgets('deux modes, « Lien » par défaut, bouton inactif sans texte', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      expect(find.text('Lien'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Lien à vérifier'), findsOneWidget);
      final analyzeButton = tester.widget<ButtonStyleButton>(
        button('Analyser le lien'),
      );
      expect(analyzeButton.onPressed, isNull);

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.text('Message à vérifier'), findsOneWidget);
      expect(find.text('Analyser le message'), findsOneWidget);
    });

    testWidgets('changer de mode garde le texte de chaque mode', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await enterText(tester, 'exemple.bf');
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.text('exemple.bf'), findsNothing);
      await enterText(tester, 'Bonjour');
      await tester.tap(find.text('Lien'));
      await tester.pumpAndSettle();
      expect(find.text('exemple.bf'), findsOneWidget);
    });

    testWidgets('annonce le schéma ajouté d’office', (tester) async {
      await pumpSafeLinkApp(tester);
      await enterText(tester, 'example.com');
      expect(
        find.text('Sera analysé comme : https://example.com/'),
        findsOneWidget,
      );
      await enterText(tester, 'https://example.com');
      expect(find.textContaining('Sera analysé comme'), findsNothing);
    });

    testWidgets('le presse-papiers n’est lu qu’à l’appui sur « Coller »', (
      tester,
    ) async {
      final clipboard = FakeClipboard('https://example.com/page');
      await pumpSafeLinkApp(tester);
      clipboard.install(tester);
      await tester.pumpAndSettle();
      expect(clipboard.reads, 0);

      await tester.tap(button('Coller'));
      await tester.pumpAndSettle();
      expect(clipboard.reads, 1);
      expect(find.text('https://example.com/page'), findsOneWidget);
    });

    testWidgets('presse-papiers vide : message clair', (tester) async {
      await pumpSafeLinkApp(tester);
      FakeClipboard(null).install(tester);
      await tester.tap(button('Coller'));
      await tester.pumpAndSettle();
      expect(
        find.text('Le presse-papiers ne contient pas de texte.'),
        findsOneWidget,
      );
    });

    testWidgets('annonce honnêtement les fonctions à venir', (tester) async {
      await pumpSafeLinkApp(tester);
      await scrollTo(tester, find.textContaining('QR code'));
      expect(
        find.textContaining('arrivent dans une prochaine version'),
        findsOneWidget,
      );
    });
  });

  group('analyse d’un lien', () {
    testWidgets('lien sans indice : jamais présenté comme sûr', (tester) async {
      await pumpSafeLinkApp(tester);
      await enterText(tester, 'https://example.com');
      await analyze(tester, 'Analyser le lien');

      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
      expect(find.text('Analyse insuffisante'), findsOneWidget);
      expect(
        find.text('Aucun indice repéré localement · Réputation non vérifiée'),
        findsOneWidget,
      );
      expect(find.textContaining('100 %'), findsNothing);
      expect(find.textContaining('sûr à'), findsNothing);
      // SafeLink n'ouvre jamais un lien analysé.
      expect(find.widgetWithText(ButtonStyleButton, 'Ouvrir'), findsNothing);
      expect(find.text('Pourquoi ce résultat ?'), findsOneWidget);
      await scrollTo(tester, find.text('Ce qui n’a pas été vérifié'));
      expect(find.text('Ce qui n’a pas été vérifié'), findsOneWidget);
    });

    testWidgets('lien suspect : verdict, indices, détails techniques', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await enterText(
        tester,
        'http://orange-money-bf.secure-login.xyz/verify'
        '?token=abcdefghijklmnopqrstuvwxyz123456',
      );
      await analyze(tester, 'Analyser le lien');

      expect(find.text('Lien suspect'), findsOneWidget);
      expect(find.text('Confiance : moyenne'), findsOneWidget);
      expect(find.text('Indice moyen'), findsWidgets);
      // Le jeton est masqué partout.
      expect(find.textContaining('abcdefghijklmnop'), findsNothing);

      await scrollTo(tester, find.text('Détails techniques'));
      await tester.tap(find.text('Détails techniques'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.textContaining('URL_BRAND_IN_SUBDOMAIN · Indice moyen'),
      );
      expect(find.textContaining('url-1.1.0'), findsOneWidget);
    });

    testWidgets('adresse non analysable : explication, pas de confiance', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await enterText(tester, 'mailto:contact@exemple.bf');
      await analyze(tester, 'Analyser le lien');
      expect(find.text('Adresse non analysable'), findsOneWidget);
      expect(find.textContaining('Confiance'), findsNothing);
    });

    testWidgets('« Nouvelle analyse » et Retour reviennent à l’accueil', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await enterText(tester, 'https://example.com');
      await analyze(tester, 'Analyser le lien');
      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(find.text('Lien à vérifier'), findsOneWidget);

      await analyze(tester, 'Analyser le lien');
      await scrollTo(tester, button('Nouvelle analyse'));
      await tester.tap(button('Nouvelle analyse'));
      await tester.pumpAndSettle();
      expect(find.text('Lien à vérifier'), findsOneWidget);
    });
  });

  group('analyse d’un message', () {
    testWidgets('synthèse, indices, lien déguisé et son résultat', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await selectMessageMode(tester);
      await enterText(tester, scamMessage);
      await analyze(tester, 'Analyser le message');

      expect(find.text('Synthèse : Danger'), findsOneWidget);
      expect(find.text('Forts indices d’arnaque'), findsOneWidget);
      expect(find.text('Indices dans le texte'), findsOneWidget);
      // Extrait sans mot ni somme coupés, numéro masqué.
      await scrollTo(
        tester,
        find.text('Extrait : « Vous avez gagné 500 000 FCFA »'),
      );
      expect(find.textContaining('70 00 00 00'), findsNothing);

      final link = find.text('http://orange-gain.xyz/retrait');
      await scrollTo(tester, link);
      expect(
        find.text('Lien suspect · Écrit sous forme déguisée'),
        findsOneWidget,
      );
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat du lien'), findsOneWidget);
      expect(find.text('Lien suspect'), findsOneWidget);
      // Flèche de retour dans la barre d'application.
      expect(find.byTooltip('Retour'), findsOneWidget);

      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(appBarTitle('Résultat de l’analyse'), findsOneWidget);
    });

    testWidgets('message ordinaire : prudence maintenue', (tester) async {
      await pumpSafeLinkApp(tester);
      await selectMessageMode(tester);
      await enterText(
        tester,
        'Salut, on se retrouve demain à 18h devant la pharmacie ?',
      );
      await analyze(tester, 'Analyser le message');
      expect(find.text('Aucun indice évident relevé'), findsOneWidget);
      expect(
        find.text('Cela ne prouve pas que le message soit honnête.'),
        findsOneWidget,
      );
      expect(find.text('Aucun lien dans ce message.'), findsOneWidget);
    });

    testWidgets('le résumé copié ne reproduit pas le message', (tester) async {
      final clipboard = FakeClipboard(null);
      await pumpSafeLinkApp(tester);
      clipboard.install(tester);
      await selectMessageMode(tester);
      await enterText(tester, scamMessage);
      await analyze(tester, 'Analyser le message');

      await scrollTo(tester, button('Copier le résumé'));
      await tester.tap(button('Copier le résumé'));
      await tester.pumpAndSettle();
      expect(clipboard.reads, 0);
      expect(clipboard.writes, hasLength(1));
      final summary = clipboard.writes.single;
      expect(summary, contains('Message analysé (texte non reproduit)'));
      expect(summary, contains('Synthèse : Danger'));
      expect(summary, contains('Lien : http://orange-gain.xyz/retrait'));
      expect(summary, isNot(contains('Félicitations')));
      expect(summary, isNot(contains('70 00 00 00')));
      expect(summary, isNot(contains('Extrait')));
      expect(
        find.text(
          'Résumé copié, sans le texte du message ni les données sensibles.',
        ),
        findsOneWidget,
      );
    });
  });

  group('états de l’analyse', () {
    testWidgets('pendant l’analyse : indicateur sans fausse progression', (
      tester,
    ) async {
      final service = ControlledService()..gate = Completer<void>();
      await pumpSafeLinkApp(tester, analysisService: service);
      await enterText(tester, 'https://example.com');
      await tester.tap(button('Analyser le lien'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Analyse en cours…'), findsOneWidget);
      // Animation continue, sans pourcentage inventé.
      expect(find.byType(Scanner), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('%'), findsNothing);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Analyse insuffisante'), findsOneWidget);
    });

    testWidgets('erreur : aucun résultat inventé, « Réessayer » relance', (
      tester,
    ) async {
      final service = ControlledService(failFirst: true);
      await pumpSafeLinkApp(tester, analysisService: service);
      await enterText(tester, 'https://example.com');
      await analyze(tester, 'Analyser le lien');

      expect(find.text('L’analyse n’a pas abouti'), findsOneWidget);
      expect(find.text('Analyse insuffisante'), findsNothing);
      expect(service.calls, 1);

      await tester.tap(button('Réessayer'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.text('Analyse insuffisante'), findsOneWidget);
    });

    testWidgets('analyser deux fois le même texte relance l’analyse', (
      tester,
    ) async {
      final service = ControlledService();
      await pumpSafeLinkApp(tester, analysisService: service);
      await enterText(tester, 'https://example.com');
      await analyze(tester, 'Analyser le lien');
      await pressBack(tester);
      await tester.pumpAndSettle();
      await analyze(tester, 'Analyser le lien');
      expect(service.calls, 2);
    });
  });

  test('le service local analyse hors du fil d’affichage', () async {
    final service = DeviceAnalysisService();
    final outcome = await service.analyze(
      AnalysisRequest(AnalysisKind.message, scamMessage),
    );
    expect(outcome, isA<MessageOutcome>());
    expect(outcome.level.name, 'danger');
    expect(
      AnalysisRequest(
        AnalysisKind.link,
        'https://secret.example/?t=1',
      ).toString(),
      isNot(contains('secret')),
    );
  });
}
