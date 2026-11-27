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

État au lot A : **types communs uniquement**, complets et testés.

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
