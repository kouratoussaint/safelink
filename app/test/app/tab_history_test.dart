import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/app/tab_history.dart';

void main() {
  test('revient aux onglets visités, du plus récent au plus ancien', () {
    final history = TabHistory()
      ..record(0, 1)
      ..record(1, 2)
      ..record(2, 3);
    expect(history.back(3), 2);
    expect(history.back(2), 1);
    expect(history.back(1), 0);
    expect(history.back(0), isNull);
  });

  test('chaque onglet n’apparaît qu’une fois, à sa dernière position', () {
    final history = TabHistory()
      ..record(0, 1)
      ..record(1, 0)
      ..record(0, 1);
    // Accueil → Historique → Accueil → Historique : un seul retour vers
    // l'Accueil, sans aller-retour.
    expect(history.visited, [0]);
    expect(history.back(1), 0);
    expect(history.back(0), isNull);
  });

  test('sans historique, un autre onglet revient à l’Accueil', () {
    final history = TabHistory();
    expect(history.back(3), 0);
  });

  test('sur l’Accueil sans historique, propose de quitter', () {
    expect(TabHistory().back(0), isNull);
  });

  test('ignore un changement vers le même onglet', () {
    final history = TabHistory()..record(2, 2);
    expect(history.visited, isEmpty);
  });

  test('ne renvoie jamais l’onglet courant', () {
    final history = TabHistory()
      ..record(0, 2)
      ..record(2, 1);
    expect(history.back(2), 0);
  });
}
