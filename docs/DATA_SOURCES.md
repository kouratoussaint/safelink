# Sources de réputation

**État au 27 novembre 2026 : vérification en ligne du nom des sites,
avec l'accord de l'utilisateur** ([ADR 0010](adr/0010-verification-en-ligne.md)).
SafeLink n'embarque et ne redistribue aucune liste de menaces. Sans accord,
ou sans connexion, chaque résultat affiche « Vérification de réputation non
disponible » et l'analyse repose sur les règles locales.

## Services consultés en ligne

Seul le nom du site (`www.exemple.com`) est envoyé aux résolveurs, et seul
le domaine enregistré (`exemple.com`) au registre ; jamais le lien complet
ni le texte d'un message. Toutes les requêtes partent du téléphone, en
HTTPS, sans serveur intermédiaire du projet.

| Service | Ce qui est demandé | Réponse utilisée | Conditions |
| --- | --- | --- | --- |
| [Quad9](https://quad9.net/service/threat-blocking/) `dns.quad9.net` (DNS sur HTTPS, HTTP/2) | Adresse du nom (type A) | Blocage : NXDOMAIN avec erreur étendue 17 « Filtered » | Service gratuit, sans inscription ni contrat ; adresses IP non conservées ([politique](https://quad9.net/privacy/policy)) |
| [Cloudflare 1.1.1.1 for Families](https://developers.cloudflare.com/1.1.1.1/setup/) `security.cloudflare-dns.com` | Adresse du nom | Blocage : réponse `0.0.0.0` | Service gratuit ouvert à tous |
| Cloudflare 1.1.1.1 `cloudflare-dns.com` | Adresse du nom | Le nom existe ou non (NXDOMAIN) | Idem |
| Serveur RDAP du registre (Verisign pour `.com`, CentralNic pour `.xyz`…) | Données publiques du domaine | Date de l'évènement « registration » | Protocole public RFC 9083 ; aucune clé |

La table des serveurs RDAP vient du [registre d'amorçage de
l'IANA](https://data.iana.org/rdap/dns.json) (RFC 9224), embarqué dans
l'application et mis à jour par `python3 tools/update_rdap_bootstrap.py`
(par pull request). Les extensions sans serveur RDAP public (dont `.bf`)
n'ont pas de date de création.

Les réponses de Quad9 et Cloudflare jugent un **nom de site**, pas une
page : une fausse page publiée sur un site légitime peut leur échapper.

## Listes téléchargeables

Ce document résume des conditions publiées ; il ne constitue pas un avis
juridique. Une confirmation écrite de chaque fournisseur reste la seule base
solide.

## Matrice des droits

| Source | Accès constaté | Conditions publiées | Décision |
| --- | --- | --- | --- |
| [PhishTank](https://phishtank.org/faq.php) | Base téléchargeable sans clé (≈ 1,5 Mo en CSV gzip). Quota mesuré : 75 téléchargements par tranche de 3 jours et par adresse IP. Nouvelles inscriptions « temporairement désactivées ». | Conditions actuelles : renvoi au contrat de licence Cisco, non consultable. Version archivée : données utilisables gratuitement, y compris commercialement ; FAQ : usage commercial et non commercial admis. Redistribution non traitée. | Candidat n° 1, en téléchargement direct par l'appareil, **seulement après confirmation écrite** de Cisco Talos |
| [Google Safe Browsing v5](https://developers.google.com/safe-browsing/terms) | Clé API dans toutes les requêtes documentées | Usage non commercial gratuit ; avertissements et attribution obligatoires | En attente : exige une clé d'API intégrée à l'APK (décision du porteur) |
| [OpenPhish Community](https://openphish.com/terms.html) | Fichier public, mis à jour toutes les 12 h | Usage personnel uniquement ; détection et développement de produit interdits sans accord écrit ; redistribution interdite | Exclu |
| [URLhaus](https://abuse.ch/terms-of-use/) | Clé d'authentification obligatoire ; ancien export anonyme : « 410 Gone » | Gratuit en usage équitable non lucratif ; pas de licence de données affichée ; œuvres dérivées interdites sans accord | Exclu du MVP ; vise les malwares, pas le phishing |
| Listes agrégées (Phishing Army, Phishing.Database…) | Publiques | Héritent des restrictions de leurs sources | Exclues |

## Mode d'intégration prévu pour une liste téléchargeable (conditionnel)

1. **Téléchargement direct par l'appareil.** Sur action de l'utilisateur et
   après un consentement dédié, le téléphone télécharge la base, la valide
   (format, taille bornée, date) et compare les liens localement. Aucune URL
   analysée ne quitte l'appareil ; le fournisseur voit l'adresse IP du
   téléphone. SafeLink ne redistribue rien.
2. **Liste dérivée publiée par le projet** : seulement avec une autorisation
   écrite de redistribution.
3. **Requête par URL** : rejetée (envoi de chaque lien à un tiers).

Une correspondance dans une liste périmée donne au plus « Lien suspect »,
avec la date du signalement. « Aucun danger connu détecté » n'est affiché
que si une source à jour a été consultée.

## Données embarquées pour l'analyse locale

Ces données ne sont pas des listes de menaces : elles servent à comprendre
la structure d'un lien, sur l'appareil.

| Donnée | Usage | Licence | Mise à jour |
| --- | --- | --- | --- |
| [Public Suffix List](https://publicsuffix.org/list/) | Trouver le domaine réellement enregistré d'un lien | MPL-2.0, notice dans l'application (Paramètres › À propos › Licences) | `tools/update_psl.py`, par pull request |
| [Unicode](https://www.unicode.org/) `confusables.txt` (UTS #39) et `Scripts.txt` | Caractères qui imitent des lettres latines ; mélange d'écritures | Licence Unicode v3, notice dans l'application | `tools/update_unicode_data.py`, par pull request |
| Marques de référence (`packages/safelink_engine/data/brands.json`) | Repérer les imitations de marques souvent visées | Données du projet ; chaque domaine renvoie à sa source | `tools/generate_brands.py`, par pull request |

## Marques de référence

La liste sert **uniquement à repérer les imitations**. Un lien vers un
domaine officiel n'est jamais déclaré sûr : la page peut être compromise,
et un domaine officiel peut héberger du contenu de tiers.

Règles d'ajout :

1. Chaque domaine officiel est justifié par une source publique et
   vérifiable, citée dans le fichier avec sa date de vérification :
   - Wikidata, propriété « site officiel » (P856) de l'entreprise ;
   - BRVM, fiche de la société cotée (rubrique « Site web »), pour les
     sociétés cotées de l'UEMOA.
   Un domaine trouvé par une simple recherche, une publicité ou un message
   n'est jamais ajouté.
2. Seuls des domaines enregistrables sont inscrits (`orange.bf`, pas
   `www.orange.bf`) ; un domaine n'appartient qu'à une marque.
3. Les mots-clés (`keywords`, cherchés à l'intérieur des noms) comptent au
   moins 5 caractères ; les noms courts ou courants (`tokens` : `orange`,
   `moov`, `dhl`) ne sont cherchés que comme mots isolés.
4. `python3 tools/generate_brands.py` valide ces règles et régénère le code ;
   la CI échoue si le code et le fichier divergent.

État au 27 novembre 2026 : 46 marques, 167 domaines officiels. Les
institutions burkinabè sans source de ce type (LONAB, CNSS, administrations
en `.gov.bf`) n'y figurent pas encore.

Limite connue : des domaines techniques appartenant aux marques
(`googleusercontent.com`, `amazonaws.com`, `tiktokcdn.com`…) contiennent le
nom de la marque sans figurer dans la liste ; ils produisent un indice de
gravité moyenne, insuffisant à lui seul pour un verdict « Lien suspect ».
