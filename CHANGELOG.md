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
- Application Flutter `com.fasosoft.safelink` : quatre onglets (Accueil,
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
- Publication automatique des APK debug en pré-versions GitHub `dev-*`,
  avec liens de téléchargement directs (`dev-apk.yml`).
- Bouton Retour : retour à l'écran précédent dans l'onglet, puis aux
  onglets visités jusqu'à l'Accueil ; double appui pour quitter.
- Signature de développement stable : tous les APK de développement sont
  signés avec la même clé et s'installent par-dessus la version précédente ;
  taille de chaque APK indiquée dans les notes de pré-version. Sans la clé,
  la publication continue avec une signature temporaire signalée.

### Ajouté — lot C (analyse locale des messages, en cours)

- Moteur : prétraitement des messages sur l'appareil (texte replié avec
  positions d'origine, phrases, citations, négations, langue) et extraction
  des liens (y compris `www.`, domaines nus et formes déguisées `hxxp`,
  `[.]`), numéros, codes USSD et montants en francs CFA.
- Moteur : règles de signaux des messages et dictionnaire français versionné
  (`fr-1.0.0`) — demande de code ou de PIN, saisie d'un secret, paiement
  anticipé, gain, menace de blocage, sortie du canal officiel, lien qui ne
  correspond pas à la marque citée, organisme cité, urgence, et variantes
  locales (transfert « par erreur », code USSD de transfert). Négations et
  citations prises en compte, extraits expurgés. Référence :
  `docs/MESSAGE_RULES.md`.

### Ajouté — lot B (analyse locale des liens)

- Moteur : Punycode (RFC 3492) et conversion des noms de domaine
  internationaux, sans dépendance réseau.
- Moteur : Public Suffix List embarquée (sections ICANN et privée), mise à
  jour par `tools/update_psl.py`, validée par les tests officiels ; licence
  MPL-2.0 affichée dans l'application.
- Moteur : lecteur d'URL conforme au standard du WHATWG pour http et https
  (identifiants avant `@`, IPv4 décimales, octales et hexadécimales, IPv6,
  ports, encodage `%XX`, barres inversées, segments `..`, caractères
  invisibles) ; chaque transformation est notée pour être montrée ; schémas
  non web, adresses e-mail et textes ordinaires refusés avec un motif.
- Moteur : caractères trompeurs (squelettes UTS #39, Unicode 18) et mélanges
  d'écritures (`pаypal` avec un « а » cyrillique).
- Moteur : 46 marques de référence (opérateurs et banques du Burkina Faso,
  paiement, transfert d'argent, réseaux sociaux…), chaque domaine officiel
  sourcé (Wikidata, BRVM) et daté ; détection des imitations : caractères
  trompeurs, fautes de frappe, nom de marque dans un domaine tiers ou un
  sous-domaine. La liste ne certifie jamais un lien.
- Moteur : analyseur de liens complet (`UrlAnalyzer`) — 28 indices
  expliqués avec gravité et confiance (identifiants trompeurs, imitations de
  marques, IP, encodage, redirections, fichiers `.apk`, raccourcisseurs…),
  verdict prudent sans réputation (`KNOWN_THREAT` impossible sans source,
  `INCONCLUSIVE` par défaut), limites et gestes recommandés, détails
  techniques, masquage des jetons et données personnelles à l'affichage.
- Corpus CC0 de plus de 200 liens annotés évalué en CI avec seuils
  bloquants, entrées aléatoires, budget de temps et contrôle d'absence
  d'entrée-sortie. Référence publique des règles : `docs/URL_RULES.md`
  (ADR 0008).

### Modifié

- Identifiant Android : `com.fasosoft.safelink`, avant toute publication.
- Revue des dépendances : vulnérabilités contrôlées par GitHub, licences par
  `tools/check_licenses.py` (pub.dev), car GitHub ne sait pas valider les
  licences des paquets Dart.
