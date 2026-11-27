# Charte d'interface

## Couleurs

La palette d'origine (cahier des charges, §4) est lisible sur le fond bleu
nuit, mais cinq couleurs sur six descendent sous le seuil WCAG AA de 4,5:1
en texte sur fond blanc. Le thème clair utilise donc des variantes plus
foncées. Les valeurs ci-dessous sont vérifiées par
`app/test/theme/contrast_test.dart`.

| Rôle | Origine | Thème clair | Thème sombre |
| --- | --- | --- | --- |
| Primaire | `#00C2A8` | `#00796B` (5,32:1 sur blanc) | `#00C2A8` (7,46:1 sur `#081E33`) |
| Accent / information | `#3BA9FF` | `#0369A1` (5,93:1) | `#3BA9FF` (6,68:1) |
| Succès | `#22C55E` | `#15803D` (5,02:1) | `#22C55E` (7,41:1) |
| Attention | `#F59E0B` | `#B45309` (5,02:1) | `#F59E0B` (7,86:1) |
| Danger | `#EF4444` | `#B91C1C` (6,47:1) | `#F87171` (6,10:1) |
| Texte secondaire | — | `#475569` | `#A9B8C9` |

Règles :

- Une couleur sémantique n'est jamais le seul porteur du sens : texte et
  icône disent la même chose.
- Bouton principal : texte blanc sur `#00796B` en clair, texte `#081E33` sur
  `#00C2A8` en sombre. Jamais de texte blanc sur la turquoise d'origine
  (2,26:1).
- Toute nouvelle couleur passe par `AppTheme` ou `SafeLinkColors` et par le
  test de contraste.

## Typographie

Poppins (titres, 600–700) et Inter (texte, 400–600), embarquées sous SIL
Open Font License 1.1. Aucune police n'est téléchargée au lancement.

## Logo

Bouclier turquoise et maillon de chaîne. Sur fond clair, le maillon passe en
bleu nuit et le bouclier en turquoise foncée (`safelink_mark_on_light.svg`),
sinon il disparaît sur le blanc. Toutes les variantes sont générées par
`tools/generate_brand_assets.py`.

## Navigation

Quatre onglets : Accueil, Historique, Conseils, Paramètres. Pas d'onglet
« Alertes » (aucune alerte temps réel sans serveur) ni « Profil » (aucun
compte).

## Bouton Retour

1. Il ferme d'abord l'écran ouvert dans l'onglet courant (par exemple
   « À propos » revient à « Paramètres »).
2. À la racine d'un onglet, il revient aux onglets visités précédemment, du
   plus récent au plus ancien, puis à l'Accueil. Chaque onglet n'apparaît
   qu'une fois dans cet historique, pour éviter les allers-retours.
3. Sur l'Accueil, un premier appui affiche « Appuyez de nouveau sur Retour
   pour quitter SafeLink » ; un second appui dans les 2 secondes ferme
   l'application. Changer d'onglet entre-temps annule la demande.

Logique : `app/lib/app/tab_history.dart` et `app/lib/app/shell.dart` ;
tests : `app/test/app/back_navigation_test.dart`, qui simulent le bouton
Retour exactement comme Android l'envoie à Flutter.

## Images d'abord, mots simples

Le public visé lit peu. L'application parle donc d'abord par images, par
couleurs et par la voix ; les phrases et le vocabulaire technique ne sont
montrés qu'à qui le demande.

- **Mode simple (par défaut)** : verdict en grand, raisons et gestes en
  pictogrammes avec deux à cinq mots ; un appui sur une vignette montre la
  phrase complète. Sources, vérifications et limites sont repliées sous
  « Voir les explications » ; les détails techniques sont absents.
- **Mode expert** (Paramètres) : tout est déplié, avec la gravité de
  chaque indice, la confiance et les détails techniques.
- **Verdict** : jauge en demi-cercle du vert au rouge dont l'aiguille
  rejoint le niveau, pictogramme dans un disque de couleur qui rebondit,
  mot d'alerte (« Danger ! », « Attention ! », « Prudence », « Rien de
  suspect », « Illisible »), libellé précis et phrase simple. Le téléphone
  vibre en cas de danger ou d'alerte.
- **« Écouter »** : la voix du téléphone lit le verdict, les raisons et
  les gestes en mots courts, sans connexion ; un second appui arrête.
- **Aperçu du lien** : photo de la page dans un cadre de téléphone
  (ADR 0011), aussi pour le premier lien d'un message. Pour un lien
  raccourci, carte « Ce lien raccourci mène à : » avec la vraie
  destination, son verdict en image et « Voir ce site en détail »
  (ADR 0012) ; le verdict en grand prend le plus grave des deux.
- **Mouvement** : les blocs du résultat arrivent l'un après l'autre ;
  l'analyse montre un radar qui tourne et les étapes « Sur le téléphone »
  puis « En ligne ». Si Android demande de réduire les animations, tout
  est affiché d'emblée.
- **Accueil** : bouclier animé, deux grandes vignettes « Lien » et
  « Message » avec un exemple (« Un SMS, un message WhatsApp »), grands
  boutons « Coller » et « Analyser ».

## Analyse et résultats

- Première ouverture : trois étapes (mission, limites, confidentialité),
  puis l'Accueil. Rien n'est demandé : ni compte, ni autorisation.
- Accueil : vignettes « Lien » ou « Message », champ de saisie,
  « Coller », « Analyser ». Le presse-papiers n'est lu qu'à l'appui sur « Coller ».
  Quand `https://` est ajouté d'office, l'adresse réellement analysée est
  affichée sous le champ.
- Pendant l'analyse : radar animé, sans pourcentage inventé, et « Analyse
  en cours… ». En
  cas d'erreur : aucun résultat affiché, bouton « Réessayer ».
- Verdict : libellé, icône et couleur disent la même chose ; un libellé
  rassurant est toujours accompagné de sa limite (« Cela ne garantit pas
  que le lien soit sûr. »). La confiance est lue par TalkBack et affichée
  en mode expert.
- Ordre des sections : verdict, adresse avec le domaine enregistré en
  gras, aperçu de la page, « Pourquoi ce résultat ? », « Que faire ? »,
  puis les explications (repliées en mode simple) et, en mode expert, les
  « Détails techniques ».
- Message : bandeau « Synthèse : <niveau> » au niveau le plus sévère entre
  le texte et ses liens, puis le verdict du texte, ses indices et chaque
  lien repéré avec son propre résultat, ouvrable en détail.
- Jamais de bouton « Ouvrir le lien ». « Copier le résumé » ne recopie ni
  le texte du message ni les extraits ; les liens y sont masqués.
- Textes : apostrophe typographique (’) et espaces avant « : ; ? ! ».

## Vérification en ligne

- Activée par défaut (ADR 0013) : la dernière étape de la présentation
  l'annonce (« Vérification en ligne activée ») avec « Continuer » ou
  « Rester hors ligne » ; interrupteur dans les paramètres. La réactiver
  depuis un résultat (« Activer ») relance l'analyse affichée.
- Sans connexion : bandeau « Pas de connexion — Vérifié seulement sur le
  téléphone » en haut du résultat, avec « Réessayer ».
- Pendant la consultation : « Vérification en ligne… » et « Seul le nom du
  site est envoyé, de façon chiffrée. »
- Section « Vérifications en ligne » : Quad9 et Cloudflare (« Non
  signalé », « Signalé comme malveillant », « Pas de réponse »), date de
  création du domaine avec son âge, existence du nom, et le nom
  effectivement envoyé.
- Sans réponse : « Aucun service n'a répondu : vérifiez votre connexion »
  et « Réessayer » ; le résultat local reste affiché.
- Section « Ce qui a été vérifié » : chaque contrôle avec son issue (coche
  verte ou indice), pour qu'un résultat sans alerte montre ce qui a été
  examiné.

## Historique

- Désactivé tant que l'utilisateur n'a pas choisi. Le choix est proposé
  sous le résultat (« Garder vos vérifications ? ») et dans l'onglet
  Historique ; « Activer » enregistre aussi la vérification affichée.
- Sous chaque résultat enregistré : « Enregistrée dans l'historique, sans
  le texte du message », « Retirer », et « Garder aussi le texte du
  message » (ou « le lien complet ») après un avertissement.
- Liste groupée par jour ; filtres « Tous / Liens / Messages », recherche
  par domaine, et volet « Niveau et période » replié par défaut pour que
  les vérifications restent visibles sur petit écran.
- Fiche : verdict, date, type, domaine, raisons enregistrées, liens d'un
  message ; « Analyser à nouveau » seulement si le contenu a été conservé ;
  suppression après confirmation.
- « Tout effacer » dans l'onglet et dans les paramètres, toujours après
  confirmation.

## Conseils, aide et confidentialité

- **Conseils** : onze fiches de prévention en vignettes, la fiche
  « Déjà piégé ? Que faire » en tête et en rouge. Chaque fiche : le piège,
  les signes, que faire, en pictogrammes, avec « Écouter » et « Vérifier
  un lien ou un message ». Signalement : plateforme officielle
  Alerte-BCLCC (`alerte.bclcc.gov.bf`).
- **Aide** (bouton « ? » de l'accueil, Paramètres) : les trois gestes, ce
  que veut dire chaque couleur, ce que SafeLink ne peut pas faire, et
  « Essayer avec un exemple ».
- **Exemples** : six exemples inventés (faux site, lien raccourci, faux
  transfert, code à composer, tombola, SMS ordinaire), analysés sur le
  téléphone seulement, jamais enregistrés, avec le bandeau « Exemple
  inventé ».
- **Confidentialité** (Paramètres) : ce qui reste sur le téléphone, ce qui
  est envoyé et à qui (texte dans `docs/CONFIDENTIALITE.md`), ce qui
  n'arrive jamais, interrupteur de la vérification en ligne.
- **Adresse inconnue** : « Page introuvable » et retour à l'accueil.
- **Aucune attente sans fin** : chaque service en ligne a son délai, et
  toute l'étape en ligne est bornée à 45 s ; au-delà, le résultat du
  téléphone s'affiche avec « Pas de connexion ».

## Typographie

Espace insécable avant « : ; ? ! » et à l'intérieur des guillemets
(« … »), pour qu'aucun signe ne se retrouve seul en début de ligne. Les
textes de l'application (`app_fr.arb`) en contiennent ; les tests qui
cherchent un texte doivent l'écrire de la même façon (copier depuis le
fichier ARB).

## Accessibilité

- Zones tactiles d'au moins 48 × 48 dp, libellés pour TalkBack, contraste :
  vérifiés automatiquement sur chaque écran, en clair et en sombre.
- Le contenu suit librement le grossissement du texte d'Android. Seule la
  barre de navigation plafonne ce grossissement, au plus 130 %, et moins sur
  les écrans étroits, pour que « Historique » ou « Paramètres » ne se coupent
  pas au milieu du mot. Les libellés restent lus en entier par TalkBack.
- Les mises en page sont testées à 320 dp de large avec un texte à 200 %,
  en mode simple tout déplié comme en mode expert ; les règles
  d'accessibilité sont vérifiées dans les deux modes.
- Les pictogrammes sont toujours accompagnés de mots ; la jauge a un
  libellé TalkBack (« Niveau de risque : Danger »).
- Les valeurs à copier (détails techniques, contenu conservé) sont du
  texte ordinaire dans une zone de sélection (`SelectionArea`) : copiables
  par appui long, sans devenir autant de champs de saisie pour TalkBack.
- Les tests chargent les vraies polices de l'application, pour que les
  mesures de contraste et de débordement correspondent au rendu réel.
- La mesure automatique du contraste se fait à la résolution logique : un
  texte informatif de 12 px y paraît plus pâle qu'à l'écran. Les textes à
  lire (notes, points de la présentation) sont donc en 14 px au moins.

## Écarts assumés avec les maquettes initiales

| Maquette | Décision |
| --- | --- |
| Onglets « Alertes » et « Profil », cloche | Remplacés par Conseils et Paramètres ; raccourci Paramètres en haut à droite |
| Anneau de progression partiellement rempli | Interdit : aucune progression fictive ; indicateur indéterminé pendant l'analyse seulement |
| Signaux de message dans un résultat de lien | Gabarits distincts pour lien et message, avec synthèse combinée |
| Icône de partage sur le résultat | Remplacée par « Copier le résumé », expurgé |
| Bouton « Ouvrir » sur le résultat | Absent : SafeLink n'ouvre jamais un lien analysé |
