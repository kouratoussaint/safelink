# Publier une version de SafeLink

Une version publique (v0.1.0-alpha, v0.2.0-beta, v1.0.0…) est signée avec
la **clé de distribution**. Elle est différente de la clé de développement
des pré-versions `dev-…` : un téléphone qui a une version de développement
doit la désinstaller avant d'installer une version publique, une seule fois.

La clé de distribution est **créée et gardée par le mainteneur**. Elle ne
passe jamais par une conversation, un courriel ou le dépôt. Si elle est
perdue, plus aucune mise à jour ne pourra s'installer par-dessus les
versions déjà diffusées : il faudrait tout réinstaller.

## 1. Créer la clé (une seule fois, sur un ordinateur)

Il faut `keytool`, fourni avec Java (JDK 17 ou plus) ou Android Studio
(dossier `jbr/bin`).

```bash
keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore safelink-release.p12 \
  -alias safelink \
  -keyalg RSA -keysize 4096 \
  -validity 10950 \
  -dname "CN=SafeLink, O=FasoSoft, C=BF"
```

- Choisissez un mot de passe long (au moins 16 caractères), différent de
  tous vos autres mots de passe. `keytool` le demande deux fois.
- `-validity 10950` : 30 ans. Google Play exige une clé valable au moins
  jusqu'en 2033.

## 2. Garder deux copies hors ligne

- Copiez `safelink-release.p12` sur **deux** supports rangés à deux
  endroits différents (deux clés USB, par exemple).
- Notez le mot de passe **à part** (papier dans un lieu sûr, ou
  gestionnaire de mots de passe).
- Ne l'envoyez à personne, ne le mettez ni dans le dépôt ni dans un
  nuage partagé.

## 3. Préparer les secrets

Convertir le fichier en texte (base64), sur une seule ligne :

- Linux : `base64 -w0 safelink-release.p12 > safelink-release.b64`
- macOS : `base64 -i safelink-release.p12 -o safelink-release.b64`
- Windows (PowerShell) :
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("safelink-release.p12")) | Set-Content -NoNewline safelink-release.b64`

Relever l'empreinte du certificat (publique, sans danger) :

```bash
keytool -list -v -keystore safelink-release.p12 -alias safelink
```

Copiez la ligne `SHA256:` : c'est elle qu'il faut donner pour l'épingler.

## 4. Créer l'environnement protégé « release » sur GitHub

Dépôt → **Settings** → **Environments** → **New environment** → nom
`release`, puis :

1. **Deployment branches and tags** : « Selected branches and tags » →
   **Add deployment branch or tag rule** → type **Tag**, motif `v*`.
   Seuls les tags de version peuvent utiliser les secrets.
2. **Required reviewers** (recommandé) : cochez et ajoutez-vous. Chaque
   publication attendra votre accord (bouton « Review deployments »).
3. **Environment secrets** → **Add environment secret**, trois fois :

| Nom | Valeur |
|---|---|
| `SAFELINK_RELEASE_KEYSTORE_BASE64` | tout le contenu de `safelink-release.b64` |
| `SAFELINK_RELEASE_KEYSTORE_PASSWORD` | le mot de passe |
| `SAFELINK_RELEASE_KEY_ALIAS` | `safelink` |

Supprimez ensuite `safelink-release.b64` : les deux copies du `.p12`
suffisent.

## 5. Épingler l'empreinte

L'empreinte SHA-256 du certificat (étape 3) est inscrite dans
`tools/release-signing-cert.sha256`, en minuscules et sans `:`. Le
workflow refuse de publier un APK signé avec une autre clé.

## 6. Publier

1. Mettre à jour `version:` dans `app/pubspec.yaml` (ex.
   `0.1.0-alpha+1`) et renommer la section `## [Non publié]` du
   `CHANGELOG.md` en `## [0.1.0-alpha] — date`.
2. Fusionner, puis pousser le tag `v0.1.0-alpha` sur ce commit.
3. `release.yml` lance les tests, construit et signe les APK, vérifie le
   certificat, les permissions et l'alignement 16 Ko, calcule les
   empreintes SHA-256, crée l'attestation de provenance et publie la
   version (pré-version si le numéro contient un tiret).
4. Si l'environnement exige une approbation : approuver dans l'onglet
   **Actions**.

## Essai sans publier

**Actions → Version publique → Run workflow** : même chemin complet avec
une clé jetable ; les APK et les notes restent trois jours en artefact,
rien n'est publié.

## Vérifier une version téléchargée

- `sha256sum -c SHA256SUMS.txt` dans le dossier des APK.
- `apksigner verify --print-certs SafeLink-….apk` : l'empreinte doit être
  celle de `tools/release-signing-cert.sha256`.
- `gh attestation verify SafeLink-….apk --repo kouratoussaint/safelink`.
