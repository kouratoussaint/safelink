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
- SafeLink ne lit pas vos SMS : vous choisissez ce que vous collez.
- Aucune vente ni aucun partage de vos données.

## Autorisation Android

Une seule : Internet, pour la vérification en ligne.

## Code source

Public et libre (GPL-3.0-or-later) : <https://github.com/kouratoussaint/safelink>.
