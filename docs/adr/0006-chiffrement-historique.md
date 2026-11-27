# 0006 — Historique : sqflite et chiffrement AES-GCM

- Statut : accepté (lot D2, 27/11/2026)

## Contexte

L'historique est facultatif et minimal par défaut, mais un domaine visité
reste une information personnelle. Les bibliothèques SQLCipher pour Flutter
publiées sont en fin de vie.

## Décision

- **Consentement** : trois états, « pas encore choisi », « activé »,
  « désactivé ». Tant que l'utilisateur n'a pas choisi, rien n'est
  enregistré, et ni la base ni la clé ne sont créées. Le choix est proposé
  sous le premier résultat et dans l'onglet Historique ; il se change dans
  les paramètres. Désactiver propose d'effacer ce qui est enregistré.
- **Stockage** : `sqflite`, qui utilise le SQLite du système Android (aucune
  bibliothèque native embarquée), fichier `historique.db` dans le dossier
  privé de l'application. Schéma versionné (version 1), colonne
  `content_type` prévue pour les futurs types de contenu.
- **En clair** (pour trier et filtrer sans tout déchiffrer) : type, niveau,
  verdict, date, version des règles, codes des indices.
- **Chiffré** en AES-256-GCM (`cryptography`, Apache-2.0) : le détail
  (domaine, domaines des liens d'un message et leurs verdicts, explications
  des indices) et, seulement sur demande explicite, le contenu complet.
  Format : version (1 octet), nonce aléatoire (12 octets), texte chiffré,
  étiquette (16 octets). Données associées : identifiant de la
  vérification et nom du champ, pour qu'une valeur recopiée ailleurs ne se
  déchiffre pas.
- **Clé** : 256 bits aléatoires, conservés par `flutter_secure_storage`
  (BSD-3-Clause, options Android par défaut : clé enveloppée par RSA-OAEP
  dans le Keystore, valeurs en AES-GCM, via Tink, Apache-2.0). Sauvegardes
  Android désactivées : la clé ne quitte pas le téléphone.
- **Jamais enregistrés** : le texte d'un message et le lien complet sans
  accord donné pour cette vérification, après un avertissement sur les
  jetons et les données personnelles ; les extraits des indices, en aucun
  cas.
- **Effacement** : `PRAGMA secure_delete` (les lignes supprimées sont
  écrasées), `VACUUM` après « Tout effacer ». Au-delà de 500 vérifications,
  les plus anciennes sont effacées.
- **Clé perdue** (restauration, Keystore réinitialisé) : les vérifications
  restent listées avec leur verdict, marquées « illisibles », et peuvent
  être supprimées ; aucune erreur bloquante.
- **Identifiants** : 128 bits aléatoires, sans ordre ni lien avec le
  contenu.

## Conséquences

- La recherche par domaine se fait après déchiffrement en mémoire,
  acceptable pour 500 vérifications au plus.
- Tink ajoute quelques centaines de kilo-octets à l'APK.
- Aucune permission Android supplémentaire.
- Les tests vérifient que le fichier de la base ne contient ni domaine, ni
  lien, ni texte en clair, et qu'une donnée altérée ou déplacée est
  refusée.
