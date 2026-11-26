import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('ouvre l’accueil avec la signature SafeLink', (tester) async {
    await pumpSafeLinkApp(tester);
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
    expect(find.bySemanticsLabel('SafeLink'), findsWidgets);
  });

  testWidgets('n’affiche que les quatre onglets prévus', (tester) async {
    await pumpSafeLinkApp(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .whereType<NavigationDestination>()
        .map((d) => d.label)
        .toList();
    expect(labels, ['Accueil', 'Historique', 'Conseils', 'Paramètres']);
    // Ni alertes « temps réel » ni compte utilisateur (cahier des charges).
    expect(find.text('Alertes'), findsNothing);
    expect(find.text('Profil'), findsNothing);
  });

  testWidgets('chaque onglet ouvre son écran', (tester) async {
    await pumpSafeLinkApp(tester);

    await tapDestination(tester, 'Historique');
    expect(appBarTitle('Historique'), findsOneWidget);
    expect(find.text('Aucune vérification enregistrée'), findsOneWidget);

    await tapDestination(tester, 'Conseils');
    expect(appBarTitle('Conseils'), findsOneWidget);
    expect(
      find.text('Ne partagez jamais un code reçu par SMS'),
      findsOneWidget,
    );

    await tapDestination(tester, 'Paramètres');
    expect(appBarTitle('Paramètres'), findsOneWidget);

    await tapDestination(tester, 'Accueil');
    expect(find.text('Vérifiez avant de cliquer.'), findsOneWidget);
  });

  testWidgets('le raccourci de l’accueil ouvre les paramètres', (tester) async {
    await pumpSafeLinkApp(tester);
    await tester.tap(find.byTooltip('Ouvrir les paramètres'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Paramètres'), findsOneWidget);
  });

  testWidgets('l’accueil ne présente aucune analyse comme disponible', (
    tester,
  ) async {
    await pumpSafeLinkApp(tester);
    expect(find.text('Version de développement'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Analyser'), findsNothing);
  });
}
