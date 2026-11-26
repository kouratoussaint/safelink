# 0002 — Licence GPL-3.0-or-later

- Statut : accepté par le porteur du projet (26/11/2026)

## Contexte

SafeLink doit rester gratuit et public. Une licence permissive permettrait
de redistribuer une version modifiée fermée, éventuellement payante ou
publicitaire.

## Décision

Code sous GNU GPL v3.0 ou ultérieure. Dépendances admises : MIT, BSD,
Apache-2.0, ISC, Zlib, MPL-2.0 (Public Suffix List), OFL-1.1 (polices),
Unicode. Contrôle automatique dans `dependency-review.yml`.

## Conséquences

- Toute version modifiée et redistribuée doit publier son code source.
- Les bibliothèques propriétaires (par exemple ML Kit) sont exclues
  (voir ADR 0003).
- Compatible avec une publication sur Google Play.
