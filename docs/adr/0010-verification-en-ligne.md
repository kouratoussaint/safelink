# 0010 — Vérification en ligne sans clé ni serveur

- Statut : accepté (27/11/2026, demande du porteur)
- Remplace en partie : [0005](0005-sources-reputation.md) pour le MVP

## Contexte

Sans source de réputation, un lien sans indice local ne peut recevoir que
« Analyse insuffisante » : la règle « pas de danger *connu* sans avoir
consulté de liste » est juste, mais l'application paraît ne rien
conclure. Les listes téléchargeables envisagées (PhishTank, OpenPhish,
URLhaus) restent bloquées par leurs conditions d'utilisation, et le cahier
des charges interdit d'embarquer une clé d'API dans l'APK.

Deux services publics, gratuits, sans inscription ni clé, bloquent les
domaines malveillants à partir de renseignements sur les menaces :

- **Quad9** (fondation à but non lucratif, Suisse) : résolveur DNS qui
  bloque les domaines signalés par une vingtaine de fournisseurs ; il ne
  conserve pas les adresses IP. Un nom bloqué reçoit NXDOMAIN avec l'erreur
  DNS étendue 17 « Filtered » (RFC 8914).
- **Cloudflare 1.1.1.1 for Families** (`security.cloudflare-dns.com`) :
  répond `0.0.0.0` (et l'erreur étendue 16 « Censored ») pour un domaine
  classé malveillant.

Les registres de noms de domaine publient par ailleurs, via RDAP
(RFC 9083, 9224), la date de création de chaque domaine : un domaine créé
quelques jours plus tôt est l'un des meilleurs indices d'hameçonnage.

## Décision

- **Consentement** : choix proposé à la dernière étape de la présentation
  (« Activer la vérification en ligne » ou « Rester hors ligne »), sous un
  résultat tant qu'il n'est pas fait, et modifiable dans les paramètres.
  Sans accord, aucune requête n'est envoyée. *Modifié par
  [0013](0013-en-ligne-par-defaut.md) : activée par défaut, refus
  possible.*
- **Données envoyées** : uniquement le nom du site (`www.exemple.com`)
  aux résolveurs, et le domaine enregistré (`exemple.com`) au serveur RDAP
  de son registre. Jamais le chemin, les paramètres, le lien complet, ni le
  texte d'un message. Le téléphone contacte les services directement : pas
  de serveur intermédiaire du projet.
- **Requêtes**, toutes en HTTPS, en parallèle, 10 s au plus par site :
  - DNS sur HTTPS (RFC 8484) en HTTP/2 (`package:http2`, exigé par Quad9)
    vers `dns.quad9.net`, `security.cloudflare-dns.com` et
    `cloudflare-dns.com` (sans filtrage, pour savoir si le nom existe) ;
  - RDAP vers le serveur du registre, trouvé dans la table d'amorçage de
    l'IANA embarquée (`tools/update_rdap_bootstrap.py`), sans service
    intermédiaire.
- **Moteur** : il reste sans entrée-sortie. L'application lui transmet les
  réponses (`OnlineEvidence`) ; il en tire les indices `URL_REPORTED`,
  `URL_DOMAIN_NEW`, `URL_DOMAIN_NOT_FOUND` et le verdict.
- **Verdict** : un blocage par l'un des deux services donne « Menace connue
  détectée », avec le nom du service. « Aucun danger connu détecté »
  exige qu'au moins un service ait répondu sans blocage, aucun indice moyen
  ou fort, et que la page réelle ne soit pas cachée (lien raccourci,
  redirection, page publiée sur un service de partage, nom inexistant).
- **Pannes** : un service qui ne répond pas est « indisponible » ; sans
  aucune réponse, le résultat local s'affiche avec « Aucun service n'a
  répondu » et « Réessayer ». Les réponses complètes sont gardées en
  mémoire pendant la session, jamais sur le disque.
- **Android** : permission `INTERNET` (seule permission), trafic en clair
  interdit (`usesCleartextTraffic="false"`).

## Conséquences

- La plupart des liens reçoivent enfin un verdict utile : « Aucun danger
  connu détecté » (avec sa limite), « Lien suspect » pour un domaine de
  quelques jours, « Menace connue détectée » pour un domaine bloqué.
- Ces services jugent le **nom du site**, pas la page : une fausse page
  publiée sur un site légitime peut leur échapper, et un site très récent
  peut ne pas encore être signalé. L'application l'écrit dans « Ce qui n'a
  pas été vérifié ».
- Quad9, Cloudflare et le registre voient l'adresse IP du téléphone et le
  nom demandé, comme lors de toute visite d'un site.
- Les extensions sans serveur RDAP public (dont `.bf`) n'ont pas de date de
  création.
- Le blocage par Quad9 et Cloudflare n'est pas un service contractuel :
  leur comportement est vérifié par des tests sur des réponses réelles
  capturées, et l'application reste utilisable s'ils changent.
- Google Safe Browsing reste possible (usage non commercial gratuit) mais
  exige une clé d'API : décision séparée.
