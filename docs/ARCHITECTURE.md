# Architecture

SafeLink sépare strictement **la décision** (moteur de détection) de
**l'affichage** (application Flutter). Le moteur est un package Dart pur, sans
dépendance à Flutter ni accès réseau ; l'application appelle le moteur,
affiche ses résultats et gère le stockage local.

```text
Entrées (toujours à l'initiative de l'utilisateur)
  saisie ou collage · partage Android · scanner QR
        │
        ▼
Application Flutter (app/)
  écrans (features/) ── contrôleurs Riverpod ── historique chiffré (facultatif)
        │ appelle, reçoit un résultat
        ▼
safelink_engine (packages/safelink_engine/), Dart pur
  analyse d'URL · analyse de message · réputation (interface)
        └──────────────► verdict combiné : le niveau le plus sévère l'emporte
```

## Moteur `safelink_engine`

État : types communs (lot A) et analyse locale complète des liens (lot B).

| Type | Rôle |
| --- | --- |
| `ContentType` | `url` ou `message` au MVP ; extensible |
| `UrlVerdict`, `MessageVerdict` | Verdicts normatifs du cahier des charges, avec leur code (`KNOWN_THREAT`…) |
| `RiskLevel` | Niveau de synthèse ; `mostSevere` garantit qu'un message rassurant ne masque jamais un lien dangereux |
| `RiskSignal` | Indice : code, gravité, confiance, raison en français, extrait expurgé (120 caractères max), source, date UTC |
| `Limitation`, `RecommendedAction` | Ce qui n'a pas été vérifié ; gestes conseillés |
| `ProviderResult`, `ThreatMatch` | Résultat d'une source de réputation, avec âge de la liste et invariants |
| `AnalysisResult` | Base commune ; exige au moins une limite par résultat |
| `ContentAnalyzer<I, R>` | Contrat d'un analyseur : pur, déterministe, sans entrée-sortie |
| `AnalysisContext` | Horloge injectable (toujours UTC) et langue |

Briques d'analyse des liens (`lib/src/url/`) :

| Type | Rôle |
| --- | --- |
| `Punycode` | Encodage et décodage RFC 3492, testés sur les vecteurs de la RFC ; entrée invalide refusée, jamais corrigée |
| `Idna` | Nom de domaine Unicode ↔ ASCII : séparateurs Unicode, NFKC, minuscules, limites de 63 et 253 caractères |
| `PublicSuffixList` | Domaine réellement enregistré (`example.co.uk`, `arnaque.blogspot.com`) ; liste embarquée, sections ICANN et privée, tests officiels |
| `UrlParser`, `ParsedUrl` | Lecture d'un lien comme un navigateur (standard URL du WHATWG) : identifiants avant `@`, IPv4 sous toutes leurs formes, IPv6, ports, `%XX`, barres inversées, segments `..` ; 2 048 caractères au plus (réglable) |
| `UrlNormalization` | Chaque transformation appliquée, avec un code et une explication montrés à l'utilisateur (ex. « https:// supposé ») |
| `UnicodeScripts`, `Confusables` | Écriture de chaque caractère et « squelette » UTS #39 : `pаypal` (« а » cyrillique), `paypa1` et `paypal` se ressemblent |
| `BrandRegistry`, `BrandMatcher` | Marques souvent imitées, domaines officiels sourcés ; repère caractères trompeurs, fautes de frappe, nom de marque dans un domaine tiers ou un sous-domaine. **Ne certifie jamais** un domaine officiel |
| `UrlRules` | Indices heuristiques avec gravité, confiance, explication et extrait masqué ; liste dans [URL_RULES.md](URL_RULES.md) |
| `UrlVerdictPolicy` | Verdict prudent : `KNOWN_THREAT` réservé à une source de réputation récente, `INCONCLUSIVE` sans source |
| `UrlMasking` | Jetons, codes, e-mails, téléphones et mots de passe masqués à l'affichage |
| `UrlAnalyzer`, `UrlAnalysisResult` | Analyse complète d'un lien : verdict, confiance, indices, limites, gestes recommandés, détails techniques |
| `UrlParseFailure` | Refus motivé : schéma non web (`mailto:`, `tel:`, `javascript:`…), adresse e-mail, texte qui n'est pas un lien, hôte ou port invalide |

Règles de conception :

- Un analyseur n'effectue **aucune** entrée-sortie ; seule la réputation,
  ajoutée au lot F, est asynchrone et isolée derrière une interface.
- Les objets sont immuables et validés à la construction : un résultat sans
  limite, une date locale ou un extrait trop long sont refusés.
- Le moteur produit des codes stables et des explications en français ; les
  libellés des verdicts sont traduits dans l'application.

## Application `app/`

| Dossier | Contenu |
| --- | --- |
| `lib/app/` | Racine, routes (go_router, quatre onglets), barre de navigation |
| `lib/core/` | Thème et jetons de couleur, réglages persistants, informations de build, licences, widgets communs |
| `lib/features/` | Un dossier par écran : `home`, `history`, `tips`, `settings` |
| `lib/l10n/` | Textes français (ARB) ; code généré non versionné |

- **État et injection** : Riverpod 3, sans génération de code.
- **Navigation** : `StatefulShellRoute` de go_router, une pile par onglet.
- **Interface** : `material_ui`, le package Material officiel découplé du
  SDK depuis Flutter 3.47 (ADR 0007).
- **Réglages** : `shared_preferences`, pour les réglages non sensibles
  uniquement (thème). L'historique utilisera une base chiffrée (ADR 0006).

## Android

- Identifiant : `com.fasosoft.safelink`, minSdk 24, targetSdk 36.
- Aucune permission au lot A ; la CI vérifie l'APK release.
- Sauvegardes cloud et transferts d'appareil désactivés
  (`allowBackup=false`, `data_extraction_rules.xml`).
- Icône adaptative vectorielle avec couche monochrome.

## Points d'extension multimédias (hors MVP)

Les futurs `ImageAnalyzer`, `DocumentAnalyzer` et `VideoAnalyzer`
s'ajouteront en étendant `ContentType` et en implémentant `ContentAnalyzer`
avec leurs propres verdicts. L'historique portera dès sa création une
colonne `content_type` et des migrations versionnées. Chaque type de média
exigera ses propres consentements : sélection explicite du fichier, aucune
lecture de la galerie, aucun envoi silencieux. Rien de cela n'est développé
au MVP.

## Décisions

Les décisions structurantes sont consignées dans [`adr/`](adr/).
