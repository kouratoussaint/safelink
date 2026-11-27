# 0011 — Google Safe Browsing et photo des pages

- Statut : accepté (27/11/2026, décision du porteur)
- Complète : [0010](0010-verification-en-ligne.md)

## Contexte

Le public visé lit peu : voir la page qu'un lien ouvre, sans l'ouvrir, dit
plus qu'une explication. Google Safe Browsing est par ailleurs la base la
plus complète contre l'hameçonnage, gratuite pour un usage non commercial,
et sait signaler une page précise sur un site légitime, ce que Quad9 et
Cloudflare ne font pas. Les deux services exigent une clé d'API.

Le porteur a choisi d'intégrer une clé Google à l'APK, malgré le cahier
des charges (qui l'excluait), et une photo prise **automatiquement** après
chaque analyse de lien, quand la vérification en ligne est acceptée.

## Décision

- **Clé** : créée par le porteur dans son projet Google Cloud, restreinte
  aux seules API « Safe Browsing » et « PageSpeed Insights », enregistrée
  dans le secret GitHub `SAFELINK_GOOGLE_API_KEY` et injectée à la
  compilation (`--dart-define`). Elle n'est jamais dans le dépôt ni dans les
  journaux. Sans secret, ces services sont absents de l'APK et l'interface
  n'en parle pas. La clé étant lisible dans l'APK, la restriction aux deux
  API gratuites limite un détournement à l'épuisement du quota : l'aperçu
  devient alors « indisponible », sans autre effet.
- **Safe Browsing v5** (`hashes:search`) : l'adresse est canonicalisée et
  découpée en 30 expressions « hôte/chemin » au plus, selon les règles de
  Google ; seuls les **4 premiers octets** de l'empreinte SHA-256 de chaque
  expression sont envoyés. Les empreintes complètes reçues sont comparées
  sur le téléphone. Les correspondances marquées `CANARY` ou `FRAME_ONLY`
  sont ignorées. Réponse JSON ou protobuf acceptée. Réponses gardées
  5 minutes en mémoire. Un signalement donne « Menace connue détectée »,
  avec l'attribution exigée par Google (« Avertissement fourni par
  Google… sa fiabilité ne peut pas être garantie »).
- **Photo de la page** : API PageSpeed Insights (navigateur de Google), qui
  charge la page sur ses serveurs et renvoie une capture d'écran mobile et
  l'adresse finale après redirection. Le téléphone ne contacte jamais le
  site. Seuls la capture et l'adresse finale sont demandées (`fields`).
  Automatique après l'analyse d'un lien, **sauf** si le lien porte un code
  personnel (jeton, identifiant, numéro), qu'une visite pourrait consommer
  ou valider : l'utilisateur décide alors (« Prendre la photo quand
  même »). Pour un message, la photo est prise quand on ouvre un lien.
- **Destination réelle** : si l'adresse finale change de domaine (lien
  raccourci, redirection), l'application l'affiche et propose de la
  vérifier.
- **Consentement** : l'accord de vérification en ligne nomme Google et dit
  que Google reçoit le lien. Il est redemandé à ceux qui l'avaient donné
  avant cet ajout (préférence `online_checks_v2`).

## Conséquences

- Google reçoit le lien complet des liens photographiés. Le texte d'un
  message n'est jamais envoyé.
- Un site peut montrer une page anodine aux robots de Google : la photo
  n'est qu'un indice, jamais une preuve.
- La capture prend 10 à 30 secondes : elle arrive après le verdict, sans le
  retarder.
- Quota gratuit de PageSpeed Insights : 25 000 photos par jour pour tout le
  projet.
