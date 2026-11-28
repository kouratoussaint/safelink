# 0014 — Raccourcis du système : sélection de texte, tuile, bulle

- Statut : accepté (28/11/2026), demande du porteur

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
3. **Bulle flottante** (lot suivant) : en option, désactivée par défaut,
   avec l'autorisation spéciale « Afficher par-dessus d'autres applis »,
   indisponible sur Android Go (Android 10+). Toucher la bulle fait la
   même chose que la tuile.

Écartés : lire l'écran par les services d'accessibilité (contraire à la
confidentialité) ; surveiller le presse-papiers en arrière-plan (interdit
depuis Android 10, et contraire au principe : SafeLink ne lit que ce qu'on
lui donne).

## Conséquences

Les deux premiers raccourcis ne demandent aucune permission et marchent sur
tous les téléphones visés (Android Go compris). Le texte copié n'est lu
qu'à la demande explicite de l'utilisateur ; Android 12+ affiche alors son
avis « SafeLink a collé depuis le presse-papiers ».
