# 0007 — Interface avec le package `material_ui`

- Statut : accepté (lot A, 26/11/2026)

## Contexte

Depuis Flutter 3.47, `package:flutter/material.dart` est déprécié : les
composants Material sont publiés dans le package `material_ui`, édité par
flutter.dev (BSD-3-Clause).

## Décision

L'application importe `package:material_ui/material_ui.dart` (version
1.11.1 au 26/11/2026) et utilise `GlobalMaterialLocalizations.delegates`
pour traduire en français les composants Material, Cupertino et widgets.

## Conséquences

Analyse statique sans avertissement de dépréciation ; une dépendance de plus,
mise à jour par Dependabot. Certains packages tiers importent encore
l'ancienne bibliothèque, sans effet sur notre code.
