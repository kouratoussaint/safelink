import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';
import 'package:safelink/features/online/online_controller.dart';

import '../helpers/pump_app.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<void> toLastStep(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tapButton(tester, 'Suivant');
  }
}

void main() {
  testWidgets('mission, limites, confidentialité, puis choix en ligne', (
    tester,
  ) async {
    final prefs = await pumpSafeLinkApp(
      tester,
      onboarded: false,
      online: OnlineChoice.undecided,
    );
    expect(find.text('Vérifiez avant de cliquer'), findsOneWidget);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tapButton(tester, 'Suivant');
    expect(find.text('Ce que SafeLink ne peut pas promettre'), findsOneWidget);
    expect(
      find.textContaining(
        'Un résultat sans signalement n’est pas une preuve de fiabilité',
      ),
      findsOneWidget,
    );

    await tapButton(tester, 'Suivant');
    expect(
      find.text('Vos données restent sur votre téléphone'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rien n’est envoyé sans votre accord'),
      findsOneWidget,
    );

    await tapButton(tester, 'Suivant');
    expect(find.text('Vérifier aussi en ligne ?'), findsOneWidget);
    expect(
      find.textContaining('Seul le nom du site est envoyé'),
      findsOneWidget,
    );
    expect(find.textContaining('Quad9 et Cloudflare'), findsOneWidget);
    expect(prefs.getBool(OnboardingController.storageKey), isNull);

    await tapButton(tester, 'Activer la vérification en ligne');
    expect(find.text('Lien à vérifier'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(prefs.getBool(OnboardingController.storageKey), isTrue);
    expect(prefs.getString(OnlineChoiceController.storageKey), 'enabled');
  });

  testWidgets('« Rester hors ligne » est retenu', (tester) async {
    final prefs = await pumpSafeLinkApp(
      tester,
      onboarded: false,
      online: OnlineChoice.undecided,
    );
    await toLastStep(tester);
    await tapButton(tester, 'Rester hors ligne');
    expect(find.text('Lien à vérifier'), findsOneWidget);
    expect(prefs.getString(OnlineChoiceController.storageKey), 'disabled');
  });

  testWidgets('Retour revient à l’étape précédente', (tester) async {
    await pumpSafeLinkApp(tester, onboarded: false);
    await tapButton(tester, 'Suivant');
    expect(find.text('Étape 2 sur 4'), findsOneWidget);
    await pressBack(tester);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
  });

  testWidgets('les étapes se parcourent aussi d’un glissement', (tester) async {
    await pumpSafeLinkApp(tester, onboarded: false);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Étape 2 sur 4'), findsOneWidget);
  });

  testWidgets('une fois vue, la présentation n’est plus montrée', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester);
    expect(find.text('Étape 1 sur 4'), findsNothing);
    expect(find.text('Lien à vérifier'), findsOneWidget);
  });
}
