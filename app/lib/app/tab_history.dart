/// Historique des onglets visités, utilisé par le bouton Retour.
///
/// Le bouton Retour ramène d'abord en arrière dans l'onglet courant (géré
/// par la navigation de chaque onglet), puis vers les onglets visités
/// précédemment, du plus récent au plus ancien, et enfin vers l'Accueil.
/// Chaque onglet n'apparaît qu'une fois, à sa dernière position, pour que
/// le retour ne fasse pas d'allers-retours inutiles.
class TabHistory {
  new({this.homeIndex = 0});

  /// Onglet de départ, dernier atteint avant de proposer de quitter.
  final int homeIndex;

  final List<int> _visited = [];

  /// Onglets visités, du plus ancien au plus récent.
  List<int> get visited => List.unmodifiable(_visited);

  /// Note le passage de l'onglet [from] à l'onglet [to].
  void record(int from, int to) {
    if (from == to) return;
    _visited
      ..remove(to)
      ..remove(from)
      ..add(from);
  }

  /// Renvoie l'onglet où revenir depuis [current] et le retire de
  /// l'historique, ou `null` si l'utilisateur est sur l'Accueil sans
  /// historique : il faut alors proposer de quitter.
  int? back(int current) {
    while (_visited.isNotEmpty) {
      final candidate = _visited.removeLast();
      if (candidate != current) return candidate;
    }
    return current == homeIndex ? null : homeIndex;
  }
}
