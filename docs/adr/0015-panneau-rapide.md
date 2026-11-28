# 0015 — Panneau rapide et bulle qui se range

- Statut : accepté (28/11/2026), demande du porteur ; précise l'ADR 0014.
  Révisé le même jour à sa demande : la bulle disparaît complètement sur
  toutes les versions (point 2).

## Contexte

Après un essai sur téléphone, le porteur demande deux changements à la
bulle flottante (ADR 0014) :

1. la toucher doit ouvrir une interface minimale, avec le nécessaire pour
   vérifier et voir le résultat, et non toute l'application ;
2. elle ne doit pas rester affichée en permanence : disparaître après un
   temps, et revenir quand un texte est copié.

Le second point bute sur Android : depuis Android 10, seules l'application
qui a le focus et le clavier par défaut peuvent lire le presse-papiers ou
être prévenues d'une copie. Un service, même au premier plan, ne l'est pas.
Les contournements connus (service d'accessibilité qui lit l'écran,
journaux système autorisés par ADB, fenêtre qui vole le focus) sont
contraires à la confidentialité ou cassent l'application du dessous.

## Décision

1. **Panneau rapide** (`QuickCheckActivity`) : activité Flutter
   transparente, non exportée, avec sa propre tâche absente des
   applications récentes (`noHistory`, `excludeFromRecents`). Une carte
   monte du bas de l'écran, l'application du dessous reste visible et
   assombrie. Le texte copié est lu une fois, quand la fenêtre a le focus
   (Android 10+ le permet alors) ; texte secret jamais lu. Le panneau
   montre : verdict en version resserrée, vrai site, vraie destination
   d'un lien raccourci, quatre raisons au plus (les plus graves d'abord),
   trois gestes au plus, « Tout voir dans SafeLink » et « Fermer ». Un
   texte avec des liens propose le même choix que le partage. Toucher à
   côté, la croix ou Retour le ferme.
   - Interface en Flutter, second moteur lancé par le point d'entrée
     `quickCheckMain` : même analyse, mêmes réglages, même historique que
     l'application, sans code dupliqué. Le service de la bulle prépare
     Flutter à l'avance pour ouvrir plus vite.
   - La bulle, la tuile du volet et la notification de la bulle ouvrent ce
     panneau. L'alias `.ClipboardCheck` disparaît.
   - « Tout voir dans SafeLink » passe par l'alias non exporté
     `.OpenCheck` : l'application refait la vérification choisie, en
     entier. Si le panneau l'a enregistrée dans l'historique, son
     identifiant suit : l'application remplace l'enregistrement, sans
     doublon.
   - L'historique est enregistré par le panneau selon le même choix que
     dans l'application. Au retour dans SafeLink, l'historique est relu
     s'il a changé (empreinte : nombre et date de la plus récente).
2. **Bulle qui disparaît** : entière pendant 8 secondes, puis cachée
   complètement. Elle est montrée entière au premier départ de SafeLink
   après son activation, après un déplacement, et :
   - **jusqu'à Android 9** : elle revient quand un lien ou un texte est
     copié. Android prévient de la copie (`OnPrimaryClipChangedListener`)
     sans montrer le texte : seul le type (`text/*`) est regardé, pour
     ignorer une image. Le texte n'est lu que si l'on touche la bulle.
   - **à partir d'Android 10** : rien ne peut la faire revenir à la copie
     (voir le contexte). Sa notification la remplace : « Un lien copié ?
     Touchez ici pour le vérifier. » ouvre le panneau. Sur Android 13 et
     suivants, la notification d'un service au premier plan n'est visible
     qu'avec l'autorisation des notifications : Paramètres la demande à
     l'activation de la bulle ; en cas de refus, il propose la tuile du
     volet.
   Elle reste cachée tant que SafeLink (application ou panneau) est à
   l'écran. Paramètres dit, selon la version, comment elle se comporte.

   Première version du même jour : sur Android 10+, la bulle se rangeait à
   moitié dans le bord, pâlie ; le porteur a préféré qu'elle disparaisse.

Nouvelle permission : `POST_NOTIFICATIONS` (Android 13+), demandée
seulement à l'activation de la bulle sur Android 10 ou plus.

Écartés : un service d'accessibilité ou la lecture des journaux pour
détecter les copies (voir le contexte) ; une fenêtre superposée en Flutter
dans le service (moins fiable : focus, clavier, TalkBack, Retour) ; une
bulle rangée au bord sur Android 10+ (première version, remplacée à la
demande du porteur).

## Conséquences

Le panneau ouvre un second moteur Flutter, le temps de la vérification :
un peu plus de mémoire, et un court délai à la première ouverture, réduit
par la préparation de Flutter dans le service. Le code Android du panneau
et de la bulle n'est pas couvert par les tests automatiques ; il le sera
par les essais sur émulateur (issue #29). La notice d'Android 12+
« SafeLink a collé depuis le presse-papiers » apparaît à chaque ouverture
du panneau, comme avec la tuile.
