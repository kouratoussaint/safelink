# Décisions d'architecture (ADR)

Une ADR est requise pour toute nouveauté qui modifie le périmètre, les
permissions, le coût, la confidentialité ou l'architecture (cahier des
charges, §14). Format : contexte, décision, conséquences.

| N° | Décision | Statut |
| --- | --- | --- |
| [0001](0001-moteur-dart-pur.md) | Moteur de détection en package Dart pur | Accepté |
| [0002](0002-licence-gpl.md) | Licence GPL-3.0-or-later | Accepté |
| [0003](0003-scanner-qr.md) | Scanner QR sans ML Kit | Proposé (tranché au lot E) |
| [0004](0004-partage-android.md) | Partage Android entrant par canal Kotlin interne | Accepté (lot E1) |
| [0005](0005-sources-reputation.md) | Sources de réputation sous condition d'accord écrit | Remplacée en partie par 0010 |
| [0006](0006-chiffrement-historique.md) | Historique : sqflite et chiffrement AES-GCM | Accepté |
| [0007](0007-material-ui.md) | Interface avec le package `material_ui` | Accepté |
| [0008](0008-regles-liens.md) | Règles heuristiques des liens et verdict sans réputation | Accepté |
| [0009](0009-verdict-messages.md) | Verdict des messages et résultat combiné | Accepté |
| [0010](0010-verification-en-ligne.md) | Vérification en ligne sans clé ni serveur (Quad9, Cloudflare, RDAP) | Accepté |
| [0011](0011-services-google.md) | Google Safe Browsing et photo des pages (clé d'API) | Accepté |
| [0012](0012-liens-raccourcis.md) | Vraie destination des liens raccourcis | Accepté |
| [0013](0013-en-ligne-par-defaut.md) | Vérification en ligne activée par défaut | Accepté |
| [0014](0014-raccourcis-systeme.md) | Raccourcis du système : sélection de texte, tuile, bulle | Accepté, précisé par 0015 |
| [0015](0015-panneau-rapide.md) | Panneau rapide et bulle qui se range | Accepté |
