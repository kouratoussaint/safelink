# Règles d'analyse des liens

Version des règles : `url-1.1.0` (moteur `safelink_engine`). SafeLink
n'ouvre jamais le lien. Les règles locales s'appliquent sur l'appareil ; si
l'utilisateur a activé la vérification en ligne, l'application consulte en
plus des sources publiques avec le seul nom du site (voir
[ADR 0010](adr/0010-verification-en-ligne.md)) et en transmet les réponses
au moteur, qui ne fait lui-même aucune requête.

## Étapes

1. **Lecture** (`UrlParser`), comme un navigateur (standard URL du WHATWG) :
   2 048 caractères au plus (réglable) ; seuls `http` et `https` sont
   analysés, les autres schémas (`javascript:`, `data:`, `file:`,
   `content:`, `intent:`, `mailto:`, `tel:`…) donnent « Adresse non
   analysable ». Sans protocole, `https://` est supposé et signalé.
2. **Normalisation** : minuscules, NFKC, Punycode, IPv4 ramenées à
   `a.b.c.d`, domaine enregistrable selon la Public Suffix List complète
   (sections ICANN et privée). Chaque transformation est montrée.
3. **Indices** locaux (`UrlRules`) et, si des éléments ont été recueillis
   en ligne, indices en ligne (`OnlineRules`), décrits ci-dessous.
4. **Verdict** (`UrlVerdictPolicy`).

## Indices

| Code | Gravité | Ce qui est repéré |
| --- | --- | --- |
| `URL_CREDENTIALS_DECEPTIVE` | forte | Un nom de site ou de marque placé avant « @ » : `https://www.paypal.com@autre-site.com` ouvre `autre-site.com` |
| `URL_BRAND_LOOKALIKE` | forte | Nom écrit avec des caractères qui imitent une marque de référence : `pаypal` (« а » cyrillique), `paypa1`, `rnicrosoft`, `mon-compte-0range` |
| `URL_BRAND_TYPO` | forte | Nom à une faute de frappe d'une marque (6 lettres au moins) : `paypall`, `facebok` |
| `URL_BRAND_DOMAIN_IN_SUBDOMAIN` | forte | Domaine officiel recopié au début d'un autre nom : `paypal.com.verification.example` |
| `URL_CREDENTIALS` | moyenne | Identifiant ou mot de passe avant « @ », sans imitation |
| `URL_BRAND_IN_DOMAIN` | moyenne | Nom de marque dans un nom enregistré par un tiers : `orange-money-bonus.top` |
| `URL_BRAND_IN_SUBDOMAIN` | moyenne | Nom de marque dans un sous-domaine d'un autre site |
| `URL_BRAND_IN_PATH` | moyenne | Nom de marque dans le chemin d'un site qui n'est le domaine officiel d'aucune marque de référence |
| `URL_BAIT_WORDS` | moyenne | Mots d'appât dans le nom enregistré (bonus, gratuit, vérification, compte, colis…) ; dans les sous-domaines, deux mots au moins |
| `URL_MIXED_SCRIPTS` | moyenne | Plusieurs alphabets mêlés dans le nom (niveau « Highly Restrictive » d'UTS #39) |
| `URL_IMITATES_LATIN` | moyenne | Nom entièrement écrit dans un autre alphabet avec des lettres qui ressemblent au latin (`сосо`) |
| `URL_IP_LITERAL` | moyenne | Adresse IP au lieu d'un nom |
| `URL_IP_UNUSUAL_NOTATION` | moyenne | IPv4 décimale, octale, hexadécimale ou abrégée (`3232235777`) |
| `URL_ENCODED_HOST` | moyenne | Nom de site écrit avec des codes `%XX` |
| `URL_INVISIBLE_CHARACTERS` | moyenne | Caractères invisibles dans le nom |
| `URL_REDIRECT_PARAMETER` | moyenne | Paramètre contenant l'adresse d'un autre site |
| `URL_APK_DOWNLOAD` | moyenne | Lien vers un fichier `.apk`, `.apks` ou `.xapk` (application installée hors Play Store) |
| `URL_BRAND_OTHER_SUFFIX` | faible | Nom d'une marque avec une extension absente de ses domaines sourcés (`paypal.bf`, ou une filiale légitime d'un autre pays) |
| `URL_UNUSUAL_HOST_CHARACTERS` | faible | Caractères pleine chasse ou séparateurs Unicode dans le nom |
| `URL_SHORTENER` | faible | Raccourcisseur connu (`bit.ly`, `tinyurl.com`…) : la destination est cachée |
| `URL_UNUSUAL_PORT` | faible | Port explicite autre que celui du protocole |
| `URL_MANY_SUBDOMAINS` | faible | Quatre sous-domaines ou plus |
| `URL_UNLISTED_SUFFIX` | faible | Extension absente de la Public Suffix List |
| `URL_SINGLE_LABEL_HOST` | faible | Nom sans extension (`https://intranet/`) |
| `URL_UNUSUAL_SLASHES` | faible | Barres obliques inversées ou en nombre inhabituel |
| `URL_INTERNATIONALIZED` | information | Nom international : sa forme technique `xn--…` est montrée |
| `URL_SHARED_HOSTING` | information | Site sur une plateforme où chacun peut créer une page (`blogspot.com`, `web.app`…) |
| `URL_UNENCRYPTED` | information | Connexion `http` non chiffrée |
| `URL_USER_CONTENT` | information | Page ou fichier publié par un tiers sur un service de partage connu (`docs.google.com`, `sites.google.com`, `dropbox.com`, `wetransfer.com`…) : la réputation du service ne dit rien de la page |

### Indices en ligne

Produits seulement à partir des réponses des consultations en ligne,
transmises par l'application (`OnlineEvidence`).

| Code | Gravité | Ce qui est repéré |
| --- | --- | --- |
| `URL_REPORTED` | forte | Une source de réputation récente (moins de 7 jours) signale le site |
| `URL_DOMAIN_NEW` | forte, moyenne ou faible | Domaine enregistré il y a moins de 7 jours (forte), de 30 jours (moyenne) ou de 90 jours (faible), d'après les données d'enregistrement (RDAP). Jamais pour un domaine officiel de marque |
| `URL_DOMAIN_NOT_FOUND` | faible | Le nom n'existe pas (ou plus) dans le DNS : la page ne peut pas s'ouvrir ; fréquent pour une arnaque déjà fermée |

Les marques de référence et leurs domaines officiels sourcés sont décrits
dans [DATA_SOURCES.md](DATA_SOURCES.md). Un domaine officiel ne produit
aucun indice favorable : il n'est jamais déclaré sûr.

## Verdict

| Verdict | Condition |
| --- | --- |
| `KNOWN_THREAT` | Une source de réputation dont la liste a moins de 7 jours signale le lien. **Aucune règle locale ne peut produire ce verdict.** |
| `SUSPICIOUS` | Au moins un indice fort, ou au moins deux indices moyens, ou une correspondance dans une liste périmée |
| `NO_KNOWN_THREAT` | Une source récente a été consultée sans correspondance, aucun indice moyen ou fort, et aucun indice qui cache la page réelle (`URL_SHORTENER`, `URL_REDIRECT_PARAMETER`, `URL_USER_CONTENT`) ni `URL_DOMAIN_NOT_FOUND` |
| `INCONCLUSIVE` | Tous les autres cas, en particulier sans vérification en ligne |
| `INVALID` | Texte vide, trop long, schéma non web, adresse e-mail, texte ordinaire, hôte ou port invalide |

Les indices faibles et informatifs n'entrent pas dans le décompte : ils
s'affichent pour expliquer, sans alourdir le verdict.

Chaque résultat porte au moins une limite : la page n'a pas été ouverte ;
la réputation n'a pas été vérifiée (hors ligne) ou ne porte que sur le nom
du site (en ligne) ; les règles locales ne repèrent que des procédés
courants.

## Affichage et confidentialité

Le lien affiché est masqué : valeurs des paramètres sensibles (`token`,
`code`, `otp`, `password`, `email`, `tel`…), longues suites de lettres et de
chiffres, adresses e-mail, numéros de téléphone et mots de passe avant
« @ » sont remplacés par `•••`. L'hôte est montré sous sa forme technique
(ASCII), qui ne peut pas tromper l'œil, à côté de sa forme lisible. Les
extraits cités par les indices sont masqués de la même façon et limités à
120 caractères.

## Évaluation

`packages/safelink_engine/test/data/url_corpus.tsv` (CC0) contient plus de
200 liens annotés : sites légitimes, imitations, cas adverses (IDN, IP
décimales, identifiants, encodage, schémas interdits, plus de 2 048
caractères). La CI exige que chaque lien obtienne son verdict attendu,
qu'aucun lien prudent ne soit déclaré suspect, qu'aucune entrée aléatoire ne
provoque d'erreur, que l'analyse reste sous 20 ms par lien en moyenne et que
le moteur n'importe aucune bibliothèque d'entrée-sortie. Les indices en
ligne sont testés à part, avec des réponses simulées.

Limites connues : des domaines techniques des marques
(`googleusercontent.com`, `amazonaws.com`, `login.microsoftonline.com`…)
contiennent leur nom sans figurer dans les sources ; ils obtiennent un
indice moyen, insuffisant seul pour « Lien suspect ».
