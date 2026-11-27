# 0012 — Vraie destination des liens raccourcis

- Statut : accepté (27/11/2026)
- Complète : [0010](0010-verification-en-ligne.md), [0011](0011-services-google.md)

## Contexte

Les arnaques passent souvent par des liens raccourcis (bit.ly,
tinyurl.com…), qui cachent la destination. Le porteur a constaté que la
photo de la page ne venait pas pour ces liens. En conditions réelles : la
photo marche quand la destination est en ligne, mais les pages d'arnaque
ferment vite ; Google répond alors « la page n'affiche rien » et ne donne
pas l'adresse de destination. L'utilisateur ne savait donc ni à quoi
ressemble la page, ni où mène le lien.

## Décision

- Avec l'accord de vérification en ligne, pour un lien dont le domaine est
  un raccourcisseur connu (`UrlRules.shorteners`), le téléphone demande au
  raccourcisseur, en HTTPS, l'adresse de redirection (`Location`) **sans
  la suivre**. Seuls des raccourcisseurs sont contactés, au plus cinq à la
  suite ; la destination ne l'est jamais. Page d'avertissement de Bitly :
  la destination est lue dans son adresse.
- La destination est vérifiée et analysée comme un lien (Quad9,
  Cloudflare, registre, Safe Browsing). Le niveau affiché est le plus
  grave entre le lien et sa destination (« Ce lien raccourci mène à un
  site dangereux »), y compris dans l'historique.
- Une carte « Ce lien raccourci mène à : » montre l'adresse, le verdict en
  image et « Voir ce site en détail ». Si le service ne répond pas :
  « Impossible de savoir où mène ce lien raccourci ».
- La photo d'une page est encadrée par le domaine de la page
  réellement photographiée. Délai de la photo porté à 2 minutes : Google
  met jusqu'à une minute pour certaines pages (46 s mesurées pour
  `wa.me` et `t.me`).
- Textes d'accord mis à jour : un lien raccourci est envoyé à son service.

### Liens d'application (complément du 27/11/2026)

Signalé par le porteur : pas d'aperçu pour `https://onelink.to/nn64xw`.
Ces services (`onelink.to`, `onelink.me`, `app.link`) envoient chaque
appareil ailleurs : un téléphone Android reçoit
`market://details?id=com.orange.myorange.ocm` (ouverture du Play Store),
un ordinateur une autre application. Le navigateur de Google, qui imite un
téléphone Android, ne peut rien afficher (`NO_FCP`).

- Ces services rejoignent la liste des raccourcisseurs (règles
  `url-1.2.0`).
- La destination est demandée en se présentant comme le navigateur d'un
  téléphone Android, pour obtenir celle qu'aurait l'utilisateur.
- Une adresse qui ouvre une application est traduite en page web :
  `market://` et `intent://` → page du Play Store (ou page de secours
  d'un `intent://`), `itms-apps://` → page de l'App Store.
- Quand la destination est connue, Google photographie directement cette
  page. Vérifié en réel : `onelink.to/nn64xw` → page Play Store
  « Orange Max it », photo reçue (22 Ko).

## Conséquences

- Le raccourcisseur reçoit le lien raccourci et l'adresse IP du
  téléphone ; il peut compter une visite. La destination, elle, ne voit
  rien.
- Certains raccourcisseurs protégés contre les robots (rb.gy,
  shorturl.at, t.ly derrière Cloudflare) peuvent refuser la demande : la
  destination reste alors inconnue, et l'application le dit.
