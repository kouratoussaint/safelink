# Corpus de SafeLink

Jeux de test synthétiques, dédiés au domaine public
([CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/deed.fr)).
Tous les textes sont inventés : aucun message privé réel n'y figure, et les
numéros de téléphone sont fictifs.

| Fichier | Contenu |
| --- | --- |
| `messages.tsv` | Messages annotés : arnaques types (codes, gains, faux recrutements, transferts « par erreur », codes USSD, menaces de blocage, colis, faux liens, faux proches), messages légitimes et pièges (codes à usage unique, alertes bancaires, reçus, conseils de sécurité, mises en garde) |

L'outil `packages/safelink_engine/tool/evaluate_messages.dart` calcule, à
chaque pull request, le taux de détection par catégorie et les fausses
alertes ; la CI échoue si un message légitime est classé « Forts indices »
ou si moins de 90 % des arnaques sont signalées.

Le corpus des liens est dans
`packages/safelink_engine/test/data/url_corpus.tsv`.

Pour proposer un cas : inventez-le entièrement (ne copiez pas un message
reçu, il contient des données personnelles), indiquez le verdict attendu et
sa raison dans la note.
