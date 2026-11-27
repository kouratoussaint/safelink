/// Chemins de navigation de l'application.
abstract final class AppRoutes {
  static const onboarding = '/bienvenue';
  static const home = '/accueil';
  static const analysis = '/accueil/analyse';
  static const linkResult = '/accueil/analyse/lien';
  static const history = '/historique';

  /// Fiche d'une vérification enregistrée.
  static String historyEntry(String id) => '$history/$id';
  static const tips = '/conseils';
  static const settings = '/parametres';
  static const about = '/parametres/a-propos';
}
