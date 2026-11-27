# 0006 — Historique : sqflite et chiffrement AES-GCM

- Statut : proposé (lot D)

## Contexte

L'historique est facultatif et minimal par défaut, mais un domaine visité
reste une information personnelle. Les bibliothèques SQLCipher pour Flutter
publiées sont en fin de vie.

## Décision

- `sqflite`, qui utilise le SQLite du système Android : aucune bibliothèque
  native embarquée.
- Champs non sensibles en clair (type, verdict, date, version des règles,
  codes de signaux) ; domaine, URL complète et texte intégral chiffrés en
  AES-GCM (`cryptography`), avec une clé aléatoire protégée par le Keystore
  Android (`flutter_secure_storage`).
- URL complète et texte intégral conservés seulement sur consentement
  explicite, entrée par entrée.

## Conséquences

La recherche par domaine se fait après déchiffrement en mémoire, acceptable
pour un historique local de taille modeste.
