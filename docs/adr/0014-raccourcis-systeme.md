# 0014 — Raccourcis du système : sélection de texte, tuile, bulle

- Statut : accepté (28/11/2026), demande du porteur ; la tuile et la
  bulle ouvrent désormais le panneau rapide, et la bulle se range
  ([ADR 0015](0015-panneau-rapide.md))

## Contexte

Le porteur souhaite vérifier un lien sans ouvrir SafeLink, comme le font
certaines applications avec une bulle flottante. Le partage (ADR 0004)
existe déjà, mais WhatsApp ne le propose pas toujours pour un message texte.
Trois raccourcis du système sont possibles ; ils n'ont pas le même coût.

## Décision

1. **Action de sélection de texte** (`ACTION_PROCESS_TEXT`, Android 6+) :
   « Vérifier avec SafeLink » dans le menu qui apparaît quand on sélectionne
   du texte. Aucune permission. Le texte sélectionné suit le chemin du
   partage (`source` = `selection`) ; il n'est jamais modifié en retour.
2. **Tuile du volet des réglages rapides** (`TileService`, Android 7+) :
   « SafeLink — Vérifier le lien copié ». Aucune permission. La tuile ouvre
   SafeLink par l'alias **non exporté** `.ClipboardCheck` (aucune autre
   application ne peut demander la lecture) ; l'activité lit le texte copié
   **une fois au premier plan**, seul moment où Android 10+ le permet, et
   une seule fois. Un texte marqué secret par Android 13+ (mot de passe,
   code) n'est pas lu. Sur Android 13+, Paramètres propose « Ajouter » la
   tuile (`requestAddTileService`) ; avant, la marche à suivre est affichée.
3. **Bulle flottante** (`BubbleService`) : en option, désactivée par
   défaut (Paramètres › Raccourcis). Autorisation spéciale « Afficher
   par-dessus d'autres applis » (`SYSTEM_ALERT_WINDOW`), accordée par
   l'utilisateur dans les réglages après une explication en pictogrammes ;
   indisponible sur Android Go (Android 10+) et avant Android 8 : la ligne
   dit alors « Non disponible sur ce téléphone ». Un service au premier
   plan de type `specialUse` la garde affichée, avec une notification
   discrète « Bulle SafeLink active » et « Arrêter ». La toucher ouvre
   SafeLink par l'alias `.ClipboardCheck` (comme la tuile) ; la glisser
   déplace ; la lâcher sur la croix la ferme et la désactive ; elle se
   cache tant que SafeLink est à l'écran. État gardé côté Android
   (`safelink_bubble`), relancée à l'ouverture de SafeLink si elle est
   choisie. Les trois permissions s'ajoutent à la liste autorisée par la
   CI (`check_apk_permissions.sh`).

Écartés : lire l'écran par les services d'accessibilité (contraire à la
confidentialité) ; surveiller le presse-papiers en arrière-plan (interdit
depuis Android 10, et contraire au principe : SafeLink ne lit que ce qu'on
lui donne).

## Conséquences

Les deux premiers raccourcis ne demandent aucune permission et marchent sur
tous les téléphones visés (Android Go compris). La bulle ajoute trois
permissions déclarées, inutilisées tant qu'elle n'est pas activée ; une
publication sur Google Play demandera de justifier le service `specialUse`
et l'affichage par-dessus les autres applications. Le texte copié n'est lu
qu'à la demande explicite de l'utilisateur ; Android 12+ affiche alors son
avis « SafeLink a collé depuis le presse-papiers ».
