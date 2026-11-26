# 0004 — Partage Android entrant par canal Kotlin interne

- Statut : proposé (lot E)

## Contexte

SafeLink doit recevoir du texte partagé (`ACTION_SEND`, `text/plain`), au
démarrage à froid comme à chaud, sans permission ni accès aux fichiers.

## Décision

Un canal de plateforme Kotlin d'environ cent lignes dans `MainActivity`,
limité à `text/plain`. Les fichiers partagés (`EXTRA_STREAM`) sont refusés
avec le message « Contenu non analysable dans cette version ».
Repli possible : `receive_sharing_intent` (Apache-2.0).

## Conséquences

Aucune dépendance supplémentaire, périmètre strictement limité au texte,
comportement testable sur émulateur par `adb shell am start`.
