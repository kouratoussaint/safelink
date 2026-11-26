# 0003 — Scanner QR sans ML Kit

- Statut : proposé ; choix final après essai comparatif au lot E

## Contexte

`mobile_scanner`, cité par le cahier des charges, s'appuie sur ML Kit. Selon
la page officielle de Google sur les données transmises par ML Kit, les API
envoient des informations d'appareil, d'application et de performance « à
des fins de diagnostic et d'analyse d'usage », sans option de
désactivation. ML Kit est en outre propriétaire, incompatible avec la
GPL-3.0 (ADR 0002).

## Décision

- Rejeter `mobile_scanner` et ML Kit.
- Choix provisoire : `flutter_zxing` (MIT, zxing-cpp compilé depuis les
  sources), entièrement local.
- Repli : `camera` (flutter.dev) et `zxing2` (Dart pur).
- Trancher par un essai en début de lot E : vitesse de décodage sur appareil
  d'entrée de gamme, alignement 16 Ko des bibliothèques natives, taille de
  l'APK, maturité (la 4.0.0 de `flutter_zxing` date du 24/11/2026).

## Conséquences

Décodage 100 % local, sans télémétrie ; l'import d'une image passe par le
sélecteur de photos système, sans permission de stockage.
