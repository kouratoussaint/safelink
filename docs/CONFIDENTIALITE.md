# Confidentialité de SafeLink

Ce texte reprend l'écran « Confidentialité » de l'application
(Paramètres → Confidentialité). Il décrit la version de développement
actuelle.

## Ce qui reste sur votre téléphone

- **Le texte de vos messages** : jamais envoyé, à personne.
- **L'historique**, s'il est activé : chiffré (AES-256-GCM, clé gardée par
  Android), effaçable à tout moment ([ADR 0006](adr/0006-chiffrement-historique.md)).
- **Vos réglages**.

## Ce qui est envoyé pour vérifier un lien

La vérification en ligne est activée par défaut et se désactive dans les
paramètres ([ADR 0013](adr/0013-en-ligne-par-defaut.md)). Toujours en
HTTPS.

| Destinataire | Ce qu'il reçoit | Pourquoi |
|---|---|---|
| Quad9 et Cloudflare | Le nom du site (`exemple.com`) | Savoir s'il est signalé ([ADR 0010](adr/0010-verification-en-ligne.md)) |
| Registre du domaine | Le nom du site | Savoir depuis quand il existe |
| Google Safe Browsing | Un préfixe de 4 octets de l'empreinte du lien, jamais le lien | Savoir si la page est signalée ([ADR 0011](adr/0011-services-google.md)) |
| Google (PageSpeed Insights) | Le lien, sauf s'il contient un code personnel | Photographier la page sans que le téléphone l'ouvre |
| Service d'un lien raccourci (bit.ly…) | Ce lien | Connaître sa vraie destination, sans l'ouvrir ([ADR 0012](adr/0012-liens-raccourcis.md)) |

Les exemples de l'aide sont analysés sur le téléphone seulement et ne
sont jamais enregistrés.

## Jamais

- Ni compte, ni publicité, ni pistage.
- SafeLink ne lit ni vos SMS ni ce que vous copiez : vous choisissez ce
  que vous lui donnez (coller, partager, sélectionner, ou toucher la tuile
  « SafeLink » ou la bulle pour vérifier le texte copié, lu à ce moment
  seulement, dans le panneau rapide). Un texte copié marqué secret (mot de
  passe, code) n'est jamais lu. Un fichier partagé n'est jamais ouvert.
- Aucune vente ni aucun partage de vos données.

## Autorisations Android

- Internet, pour la vérification en ligne.
- Seulement si vous activez la **bulle flottante** (Paramètres ›
  Raccourcis, désactivée par défaut) : « Afficher par-dessus d'autres
  applis », que vous accordez vous-même dans les réglages d'Android, et un
  service au premier plan qui la garde affichée (notification « Bulle
  SafeLink active »). La bulle ne lit ni votre écran ni ce que vous
  copiez : la toucher ouvre le panneau rapide, qui lit alors le texte
  copié, comme la tuile du volet. Elle disparaît après quelques secondes.
  Jusqu'à Android 9, Android prévient la bulle qu'un texte vient d'être
  copié, pour qu'elle réapparaisse ; elle ne voit que le type du contenu
  (texte ou image), jamais le texte. À partir d'Android 10, Android ne
  prévient plus d'une copie : la notification de la bulle la remplace,
  et sur Android 13 et suivants SafeLink demande l'autorisation des
  notifications pour qu'elle soit visible (refus possible : la tuile du
  volet fait la même chose). Indisponible sur Android Go.
- Recevoir un texte partagé ou sélectionné, et la tuile du volet, ne
  demandent aucune autorisation.

## Code source

Public et libre (GPL-3.0-or-later) : <https://github.com/kouratoussaint/safelink>.
