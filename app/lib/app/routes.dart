/// Chemins de navigation de l'application.
abstract final class AppRoutes {
  static const onboarding = '/bienvenue';
  static const home = '/accueil';
  static const analysis = '/accueil/analyse';
  static const linkResult = '/accueil/analyse/lien';

  /// Partage reçu d'une autre application : choix ou refus expliqué.
  static const share = '/accueil/partage';
  static const history = '/historique';

  /// Fiche d'une vérification enregistrée.
  static String historyEntry(String id) => '$history/$id';
  static const tips = '/conseils';

  /// Fiche de prévention.
  static String tip(String id) => '$tips/$id';

  /// Aide : comment faire, comprendre le résultat, limites.
  static const help = '/accueil/aide';

  /// Exemples fictifs à analyser, jamais enregistrés.
  static const examples = '/accueil/aide/exemples';

  /// Confidentialité : ce qui reste sur le téléphone, ce qui est envoyé.
  static const privacy = '/parametres/confidentialite';
  static const settings = '/parametres';
  static const about = '/parametres/a-propos';
}
