import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/onboarding/onboarding_controller.dart';

import '../helpers/pump_app.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
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

void main() {
  testWidgets('première ouverture : mission, limites, confidentialité', (
    tester,
  ) async {
    final prefs = await pumpSafeLinkApp(tester, onboarded: false);
    expect(find.text('Vérifiez avant de cliquer'), findsOneWidget);
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
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
    expect(find.textContaining('Pas de compte'), findsOneWidget);
    expect(prefs.getBool(OnboardingController.storageKey), isNull);

    await tapButton(tester, 'Commencer');
    expect(find.text('Lien à vérifier'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(prefs.getBool(OnboardingController.storageKey), isTrue);
  });

  testWidgets('Retour revient à l’étape précédente', (tester) async {
    await pumpSafeLinkApp(tester, onboarded: false);
    await tapButton(tester, 'Suivant');
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
    await pressBack(tester);
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
  });

  testWidgets('les étapes se parcourent aussi d’un glissement', (tester) async {
    await pumpSafeLinkApp(tester, onboarded: false);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
  });

  testWidgets('une fois vue, la présentation n’est plus montrée', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester);
    expect(find.text('Étape 1 sur 3'), findsNothing);
    expect(find.text('Lien à vérifier'), findsOneWidget);
  });
}
