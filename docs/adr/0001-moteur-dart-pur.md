# 0001 — Moteur de détection en package Dart pur

- Statut : accepté (lot A, 26/11/2026)

## Contexte

Le cahier des charges exige des verdicts explicables, testés, indépendants
de l'interface et des modèles réseau, et une architecture extensible aux
médias.

## Décision

Toute la logique de détection vit dans `packages/safelink_engine`, package
Dart pur : aucune dépendance à Flutter, aucun accès réseau, objets immuables
validés à la construction. L'application en dépend par chemin local.

## Conséquences

- Tests rapides (`dart test`), exécutables sans émulateur ; couverture
  minimale de 90 % imposée par la CI.
- L'interface ne peut pas fabriquer un verdict : elle affiche ceux du moteur.
- Un outil en ligne de commande pourra réutiliser le moteur pour évaluer le
  corpus de test (lot C).
