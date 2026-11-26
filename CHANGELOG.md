# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Versions : [gestion sémantique](https://semver.org/lang/fr/), tags
`vMAJEUR.MINEUR.CORRECTIF`.

## [Non publié]

### Ajouté — lot A (fondations)

- Moteur `safelink_engine` en Dart pur : types communs (verdicts normatifs
  des liens et des messages, niveaux de synthèse, indices, limites, gestes
  recommandés, résultats de sources de réputation, contrat
  `ContentAnalyzer`), validés et couverts à 100 % par les tests.
- Application Flutter `com.safelink.fasosoft` : quatre onglets (Accueil,
  Historique, Conseils, Paramètres), thèmes clair et sombre aux contrastes
  WCAG AA vérifiés, polices Poppins et Inter embarquées, interface en
  français, choix du thème, écran « À propos ».
- Icône adaptative vectorielle avec couche monochrome (Android 13+) et logo
  redessiné en vectoriel, générés par `tools/generate_brand_assets.py`.
- Manifeste Android sans aucune permission ; sauvegardes cloud et transferts
  d'appareil désactivés.
- Tests d'accessibilité automatiques (zones tactiles, libellés, contraste)
  sur tous les écrans, en clair et en sombre, et tests de mise en page à
  320 dp avec texte agrandi à 200 %.
- CI GitHub Actions : formatage, analyse, tests, couverture, APK debug,
  contrôle des permissions de l'APK release ; revue des dépendances ;
  Dependabot.
- Documentation : compilation, architecture, décisions (ADR), sources de
  réputation, charte d'interface.
