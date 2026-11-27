# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Versions : [gestion sémantique](https://semver.org/lang/fr/), tags
`vMAJEUR.MINEUR.CORRECTIF`.

## [Non publié]

### Modifié — Refonte « Clarté », étape 3 : paramètres, présentation

- Paramètres en cartes groupées (vérification en ligne, historique,
  apparence, aide), chaque réglage avec sa pastille ; « À propos » en
  cartes.
- Présentation de première ouverture : grande illustration entourée d'un
  halo, texte centré, points dans une carte, « Écouter » sur chaque étape,
  points de progression.
- Textes inutilisés retirés.

### Modifié — Refonte « Clarté », étape 2 : partage, historique, conseils

- Grands titres pour les onglets Historique, Conseils et Paramètres.
- Historique : filtres en segments, une carte par jour, chaque
  vérification avec sa pastille de couleur ; fiche avec le verdict sur
  fond teinté.
- Conseils : vignettes blanches de même hauteur, « Déjà piégé ? » en carte
  rouge pleine.
- Partage reçu : grand pictogramme entouré d'un halo, choix en cartes ;
  champs de saisie sur fond blanc.

### Modifié — Refonte « Clarté », étape 1 : accueil et résultats

- Nouveau style clair et épuré (piste A des maquettes) : fond gris très
  clair, cartes blanches à ombre douce, pastilles arrondies, un seul
  bouton principal par écran ; thème sombre accordé.
- Accueil : titre et accroche, choix Lien / Message en segments, carte de
  saisie, raccourcis « Partager », « Exemples » et QR code (bientôt).
- Résultat : verdict sur carte teintée avec halo animé et barre de niveau
  en quatre couleurs, « Le vrai site » en grand, raisons en grille,
  gestes en liste.

### Ajouté — Partager vers SafeLink (lot E1)

- « Partager → Vérifier avec SafeLink » depuis une autre application
  (texte seulement, aucune permission), application fermée ou ouverte
  ([ADR 0004](docs/adr/0004-partage-android.md), acceptée).
- Un lien seul ou un texte sans lien est analysé tout de suite ; sinon,
  écran « Partage reçu » : « Tout le message » ou « Le lien seulement »,
  puis choix du lien s'il y en a plusieurs ; « Écouter ».
- Photos, vidéos, fichiers et partages vides refusés avec une explication
  en pictogrammes ; fichier joint à un texte jamais ouvert ; texte trop
  long : seul le début est vérifié, avec un avertissement.
- Un partage reçu pendant la présentation de première ouverture attend
  qu'elle soit terminée.
- Accueil et aide : comment partager, en trois pictogrammes.

### Ajouté — Publication des versions publiques (lot D4)

- `release.yml` : sur un tag `v…`, tests, APK signés avec la clé de
  distribution (environnement protégé `release`), vérification du
  certificat épinglé, des permissions et de l'alignement 16 Ko,
  empreintes SHA-256, attestation de provenance, notes tirées du
  CHANGELOG. Essai complet sans publier, avec une clé jetable.
- `docs/RELEASE.md` : créer et garder la clé, préparer l'environnement,
  publier, vérifier une version.

### Ajouté — Conseils, aide, exemples, confidentialité (lot D3)

- Onze fiches de prévention en pictogrammes (codes secrets, faux
  transfert « par erreur », codes à composer, faux agents, applications
  hors Play Store, gains, faux emplois, liens, QR codes, messages qui
  pressent) et « Déjà piégé ? Que faire », avec signalement sur
  Alerte-BCLCC ; « Écouter » sur chaque fiche.
- Aide : les trois gestes, la signification de chaque couleur, les
  limites ; six exemples inventés, jamais envoyés ni enregistrés.
- Écran Confidentialité : ce qui reste sur le téléphone, ce qui est
  envoyé et à qui ; `docs/CONFIDENTIALITE.md`.
- Page « introuvable » en français ; étape en ligne bornée à 45 s.
- Espaces insécables dans la ponctuation française.

### Modifié — Vérification en ligne activée par défaut (ADR 0013)

- Analyse en ligne prioritaire : activée dès l'installation, annoncée à
  la dernière étape de la présentation (« Continuer » ou « Rester hors
  ligne ») et désactivable dans les paramètres ; un refus déjà donné est
  respecté.
- Carte « Vérifier aussi en ligne ? » retirée.
- Sans connexion : bandeau « Pas de connexion » en haut du résultat, avec
  « Réessayer » ; l'analyse sur le téléphone prend le relais.

### Ajouté — Liens d'application (onelink.to…)

- `onelink.to`, `onelink.me`, `app.link` et `urlz.fr` traités comme des
  raccourcisseurs (règles `url-1.2.0`).
- Destination demandée comme le ferait un téléphone Android ; une
  ouverture du Play Store (`market://`, `intent://`) ou de l'App Store
  devient la page web correspondante.
- La photo est prise directement sur la destination quand elle est
  connue : aperçu de la page Play Store au lieu d'une page vide.

### Ajouté — Vraie destination des liens raccourcis (ADR 0012)

- Pour bit.ly, tinyurl.com et les autres raccourcisseurs connus, la vraie
  destination est demandée au service, sans jamais être ouverte, puis
  vérifiée et analysée. Le verdict prend le plus grave des deux ; carte
  « Ce lien raccourci mène à : » avec « Voir ce site en détail ».
- Photo : cadre au nom de la page réellement photographiée ; délai porté
  à 2 minutes.

### Corrigé — Services Google vérifiés en conditions réelles

- Safe Browsing : la requête demandait du JSON, que `hashes:search`
  refuse ; la réponse est désormais lue en protobuf.
- Photo des pages : le filtre de champs visait l'audit
  `final-screenshot`, refusé par Google ; il porte maintenant sur les
  audits, avec réponse compressée.
- Réponses réelles de Google ajoutées aux tests.

### Modifié — Images d'abord, mots simples, voix

- Mode simple par défaut : verdict en grand avec jauge animée du vert au
  rouge, pictogramme et mot d'alerte ; raisons et gestes en pictogrammes
  avec quelques mots, phrase complète au toucher ; explications repliées
  sous « Voir les explications ». Mode expert dans les Paramètres.
- Bouton « Écouter » : lecture à voix haute du verdict et des gestes, avec
  la voix du téléphone (flutter_tts, MIT), sans connexion.
- Animations : blocs qui arrivent l'un après l'autre, radar pendant
  l'analyse, bouclier animé à l'accueil ; vibration en cas de danger ;
  aucune animation si Android demande de les réduire.
- Accueil : grandes vignettes « Lien » / « Message » et grands boutons.
- Aperçu automatique du premier lien d'un message.

### Ajouté — Google Safe Browsing et photo des pages (ADR 0011)

- Google Safe Browsing v5 : canonicalisation et expressions selon les
  règles de Google, seuls des préfixes de 4 octets envoyés, comparaison des
  empreintes sur le téléphone, réponses JSON ou protobuf, attribution
  affichée.
- Photo automatique de la page par les serveurs de Google (PageSpeed
  Insights) : le téléphone ne contacte jamais le site ; capture dans un
  cadre de téléphone avec le vrai domaine en barre d'adresse et un bandeau
  « Faux site probable » si le lien est suspect ; agrandissement ; vraie
  destination après redirection, à vérifier d'un appui. Pas de photo
  automatique pour un lien portant un code personnel.
- Clé injectée à la compilation depuis le secret
  `SAFELINK_GOOGLE_API_KEY` ; sans clé, ces services sont absents.
  L'accord de vérification en ligne nomme Google et est redemandé.

### Ajouté — vérification en ligne (ADR 0010)

- Vérification en ligne du nom des sites, avec l'accord de l'utilisateur
  (dernière étape de la présentation, proposition sous un résultat,
  interrupteur dans les paramètres) : Quad9 et Cloudflare (listes de
  domaines malveillants, par DNS sur HTTPS en HTTP/2), existence du nom,
  date de création du domaine auprès du registre (RDAP, table d'amorçage
  de l'IANA embarquée). Seul le nom du site est envoyé ; jamais le lien
  complet ni le texte d'un message ; aucune clé, aucun serveur du projet.
- Moteur `url-1.1.0` : `OnlineEvidence`, indices `URL_REPORTED`,
  `URL_DOMAIN_NEW` (moins de 7, 30 ou 90 jours), `URL_DOMAIN_NOT_FOUND`,
  `URL_USER_CONTENT` (page publiée sur un service de partage) ;
  « Aucun danger connu détecté » seulement sans indice moyen ni page
  cachée ; limite « la vérification porte sur le nom du site ».
- Résultats : sections « Vérifications en ligne » et « Ce qui a été
  vérifié » (liens et messages), étape « Vérification en ligne… », état
  « Aucun service n'a répondu » avec « Réessayer ».
- Android : permission `INTERNET` (seule permission), trafic en clair
  interdit ; la CI n'autorise que celle-ci.
- Tests : messages DNS (dont une vraie réponse de blocage de Quad9),
  consultations simulées (blocage, nom inexistant, registre, panne, délai),
  analyse en vrais isolats, parcours, consentement, accessibilité et mise
  en page des nouvelles sections.

### Ajouté — lot D2 (historique chiffré)

- Historique facultatif, désactivé tant que l'utilisateur n'a pas choisi :
  proposition sous le premier résultat et dans l'onglet, interrupteur dans
  les paramètres. Rien n'est créé (ni base, ni clé) avant l'activation.
- Enregistrement minimal : type, verdict, date, version des règles, codes
  et explications des indices, domaine ; jamais d'extrait. Le texte d'un
  message ou le lien complet n'est gardé que sur demande, après un
  avertissement, et peut être retiré.
- Base SQLite du système (`sqflite`) ; domaine, raisons et contenu chiffrés
  en AES-256-GCM, clé aléatoire protégée par le Keystore d'Android
  (`flutter_secure_storage`) ; lignes effacées écrasées ; 500 vérifications
  au plus (ADR 0006 acceptée).
- Onglet Historique : liste par jour, filtres Tous / Liens / Messages,
  recherche par domaine, niveau et période ; fiche détaillée,
  « Analyser à nouveau » si le contenu a été gardé, suppression unitaire et
  « Tout effacer » avec confirmation ; vérifications devenues illisibles
  signalées et supprimables.
- Tests : chiffrement (altération, déplacement, clé perdue), contenu du
  fichier sans donnée en clair, consentement, filtres, accessibilité et
  mise en page des nouveaux écrans.

### Modifié — lot D2

- Détails techniques : valeurs copiables par appui long dans une zone de
  sélection, au lieu de champs sélectionnables séparés.

### Ajouté — lot D1 (accueil, analyse et résultats)

- Présentation de première ouverture en trois étapes (mission, limites,
  confidentialité), sans compte ni autorisation ; Retour revient à l'étape
  précédente.
- Accueil à deux modes « Lien » et « Message » : champ de saisie, bouton
  « Coller » (le presse-papiers n'est lu qu'à l'appui), aperçu de l'adresse
  analysée quand `https://` est ajouté d'office, résultat en deux actions.
- Analyse locale hors du fil d'affichage (isolat), indicateur sans fausse
  progression, écran d'erreur avec « Réessayer » qui n'invente aucun
  résultat.
- Écrans de résultat des liens et des messages : verdict (libellé, icône et
  couleur), confiance, « Pourquoi ce résultat ? », « Ce qui n'a pas été
  vérifié », « Que faire ? », détails techniques repliables ; pour un
  message, synthèse au niveau le plus sévère, indices du texte et liens
  repérés avec leur propre résultat. Aucun bouton pour ouvrir un lien.
- « Copier le résumé » : verdicts, raisons, gestes et liens masqués, sans
  le texte du message ni les extraits.
- Tests : parcours complets, états d'attente et d'erreur, résumé expurgé,
  accessibilité et mise en page (320 dp, texte à 200 %) des nouveaux
  écrans.

### Modifié — lot D1

- Moteur : un extrait de message ne coupe plus un mot ni une somme
  (« vous avez gagné 500 000 FCFA » au lieu de « vous avez gagné 5 »).
- Textes de l'application : apostrophe typographique (’), comme dans les
  explications du moteur.

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

### Modifié — APK de développement

- Les pré-versions `dev-*` publient désormais des APK optimisés (build
  release) : environ 19 Mo au lieu de 100 Mo (arm64-v8a) et 17 Mo au lieu
  de 79 Mo (armeabi-v7a), même clé de signature, aucune permission Android ;
  permissions et alignement 16 Ko vérifiés avant publication.

### Ajouté — lot C (analyse locale des messages)

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
- Moteur : verdict des messages (cinq verdicts, jamais « authentique »),
  limites et gestes recommandés selon les indices ; résultat combiné texte +
  liens au niveau le plus sévère (ADR 0009).
- Corpus CC0 de 184 messages inventés (`data/corpus/messages.tsv`) et outil
  d'évaluation lancé en CI avec seuils bloquants : aucun message légitime en
  « Forts indices », au moins 90 % des arnaques signalées.

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
