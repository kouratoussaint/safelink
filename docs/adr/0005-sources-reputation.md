# 0005 — Sources de réputation sous condition d'accord écrit

- Statut : remplacée en partie par [0010](0010-verification-en-ligne.md)
  (27/11/2026) : le MVP vérifie en ligne le nom des sites auprès de Quad9
  et Cloudflare, sans liste téléchargée. Les conditions ci-dessous restent
  valables pour toute liste téléchargeable (PhishTank…).

## Contexte

Aucune source de réputation n'est utilisable aujourd'hui avec une base
juridique suffisante (voir `docs/DATA_SOURCES.md`). Le cahier des charges
interdit de simuler une vérification et d'embarquer une clé dans l'APK.

## Décision

- Aucune source au MVP tant qu'une autorisation écrite n'est pas obtenue.
- Mode visé pour PhishTank : téléchargement direct de la base par
  l'appareil, sur action de l'utilisateur et avec consentement dédié ;
  comparaison locale ; aucune redistribution par le projet.
- En l'absence d'accord avant le lot G, la v1.0 sort sans permission
  INTERNET, entièrement hors ligne, avec la mention « Vérification de
  réputation non disponible ».
- `NO_KNOWN_THREAT` n'est produit que si une liste à jour a été consultée ;
  sinon `INCONCLUSIVE`.

## Conséquences

En v1.0 hors ligne, aucun lien ne reçoit « Aucun danger connu détecté ».
C'est le prix de l'honnêteté : sans source consultée, le danger n'est pas
« connu ».
