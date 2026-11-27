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

## Analyse et résultats

- Première ouverture : trois étapes (mission, limites, confidentialité),
  puis l'Accueil. Rien n'est demandé : ni compte, ni autorisation.
- Accueil : choix « Lien » ou « Message », champ de saisie, « Coller »,
  « Analyser ». Le presse-papiers n'est lu qu'à l'appui sur « Coller ».
  Quand `https://` est ajouté d'office, l'adresse réellement analysée est
  affichée sous le champ.
- Pendant l'analyse : indicateur indéterminé et « Analyse en cours… ». En
  cas d'erreur : aucun résultat affiché, bouton « Réessayer ».
- Verdict : libellé, icône et couleur disent la même chose ; un libellé
  rassurant est toujours accompagné de sa limite (« Cela ne garantit pas
  que le lien soit sûr. »). La confiance est affichée en toutes lettres.
- Ordre des sections : verdict, lien avec le domaine enregistré en gras,
  « Pourquoi ce résultat ? », « Que faire ? », « Ce qui n'a pas été
  vérifié », « Détails techniques » repliés.
- Message : bandeau « Synthèse : <niveau> » au niveau le plus sévère entre
  le texte et ses liens, puis le verdict du texte, ses indices et chaque
  lien repéré avec son propre résultat, ouvrable en détail.
- Jamais de bouton « Ouvrir le lien ». « Copier le résumé » ne recopie ni
  le texte du message ni les extraits ; les liens y sont masqués.
- Textes : apostrophe typographique (’) et espaces avant « : ; ? ! ».

## Accessibilité

- Zones tactiles d'au moins 48 × 48 dp, libellés pour TalkBack, contraste :
  vérifiés automatiquement sur chaque écran, en clair et en sombre.
- Le contenu suit librement le grossissement du texte d'Android. Seule la
  barre de navigation plafonne ce grossissement, au plus 130 %, et moins sur
  les écrans étroits, pour que « Historique » ou « Paramètres » ne se coupent
  pas au milieu du mot. Les libellés restent lus en entier par TalkBack.
- Les mises en page sont testées à 320 dp de large avec un texte à 200 %.
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
