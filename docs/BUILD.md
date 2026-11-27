# Compiler SafeLink

Ce guide permet de reproduire, sur sa propre machine, ce que fait la CI :
formatage, analyse, tests et compilation de l'APK.

## Versions de référence

| Outil | Version | Où elle est fixée |
| --- | --- | --- |
| Flutter | 3.50.1 (Dart 3.14.0) | `.flutter-version`, `app/pubspec.yaml` (`environment.flutter`) |
| JDK | 17 minimum, 21 recommandé | `.github/workflows/ci.yml` |
| SDK Android | compileSdk 36, targetSdk 36, minSdk 24 | `app/android/app/build.gradle.kts` |
| NDK | 28.2.13676358 (valeur de Flutter 3.50.1) | installé automatiquement par Gradle |
| Android Gradle Plugin / Kotlin / Gradle | 9.3.1 / 2.4.20 / 9.5.0 | `app/android/settings.gradle.kts`, wrapper Gradle |

targetSdk 36 est exigé par Google Play pour toute nouvelle application ou
mise à jour depuis le 31 août 2026.

## Installation

1. **Flutter 3.50.1.** Télécharger l'archive stable depuis
   <https://docs.flutter.dev/install/archive> ou cloner le tag :

   ```bash
   git clone --depth 1 --branch 3.50.1 https://github.com/flutter/flutter.git ~/flutter
   export PATH="$HOME/flutter/bin:$PATH"
   flutter --version   # doit afficher 3.50.1, révision ae9b586f34
   ```

2. **JDK 21** (ou 17), par exemple le paquet `openjdk-21-jdk`.
3. **SDK Android** : Android Studio, ou les *command-line tools* puis :

   ```bash
   sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
   sdkmanager --licenses
   flutter config --android-sdk "$ANDROID_HOME"
   flutter doctor
   ```

## Vérifier et compiler

```bash
# Moteur (Dart pur)
cd packages/safelink_engine
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test --coverage-path=coverage/lcov.info
python3 ../../tools/check_coverage.py coverage/lcov.info 90

# Application
cd ../../app
flutter pub get --enforce-lockfile   # génère aussi les traductions
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

L'APK debug est produit dans `app/build/app/outputs/flutter-apk/app-debug.apk`
et s'installe avec `adb install`. Il pèse environ 100 Mo, car il contient le
code non compilé et les outils de diagnostic. Pour un APK optimisé d'environ
20 Mo par architecture, comme ceux des pré-versions de développement :

```bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

### Contrôle des permissions

```bash
flutter build apk --release
../tools/check_apk_permissions.sh build/app/outputs/flutter-apk/app-release.apk
```

Le script échoue si l'APK déclare une permission non listée. La CI
autorise seulement `android.permission.INTERNET` (vérification en ligne,
ADR 0010) :

```bash
../tools/check_apk_permissions.sh build/app/outputs/flutter-apk/app-release.apk android.permission.INTERNET
```
 Les builds release des lots A à C sont signés avec
la clé de débogage : ils ne servent qu'à ce contrôle et ne doivent jamais
être distribués.

### Licences des dépendances

```bash
python3 tools/check_licenses.py app/pubspec.lock packages/safelink_engine/pubspec.lock
```

Le script interroge pub.dev et échoue si une dépendance n'a pas de licence
compatible avec la GPL-3.0-or-later. Il tourne à chaque pull request dans
`dependency-review.yml`, à côté du contrôle des vulnérabilités de GitHub.

### Traductions

Les textes sont dans `app/lib/l10n/app_fr.arb`. Le code Dart correspondant
(`app/lib/l10n/generated/`) est généré par `flutter pub get` ou
`flutter gen-l10n` et n'est pas versionné.

### Public Suffix List

Le moteur embarque la [Public Suffix List](https://publicsuffix.org/list/)
(MPL-2.0) sous forme de code Dart généré. Pour la mettre à jour :

```bash
python3 tools/update_psl.py   # télécharge depuis publicsuffix.org
cd packages/safelink_engine && dart test test/url
```

Le script régénère `lib/src/url/psl_data.g.dart` (date et empreinte SHA-256
de la liste) et les tests officiels `test/data/psl_tests.txt`. La mise à
jour fait l'objet d'une pull request ordinaire, relue comme du code.

### Données Unicode et marques de référence

```bash
python3 tools/update_unicode_data.py   # confusables.txt et Scripts.txt d'Unicode
python3 tools/generate_brands.py       # après modification de data/brands.json
```

### Logo et icônes

Toutes les ressources graphiques sont générées depuis une seule géométrie :

```bash
python3 tools/generate_brand_assets.py   # nécessite rsvg-convert (librsvg2-bin)
```

## Intégration continue

`ci.yml` installe Flutter sans action tierce, en clonant le tag de
`.flutter-version`, puis vérifie que la révision clonée est bien celle du
manifeste officiel des versions stables. Toutes les actions GitHub sont
épinglées par SHA de commit et mises à jour par Dependabot.

## APK de développement publiés

`dev-apk.yml` compile les APK optimisés (`--release`, arm64-v8a et
armeabi-v7a) à chaque mise à jour de `main` ou d'une branche `lot-*`,
vérifie leur signature, leurs permissions (Internet seulement) et leur alignement 16 Ko,
puis crée la pré-version
`dev-<7 premiers caractères de la révision>` avec les APK et
`SHA256SUMS.txt`. Liens directs :
`https://github.com/kouratoussaint/safelink/releases/download/dev-<révision>/<fichier>.apk`.
Seules les cinq dernières pré-versions `dev-*` sont conservées. Le droit
d'écriture est limité à ce job, qui ne s'exécute jamais depuis une copie du
dépôt.

### Signature de développement

Tous les APK de développement sont signés avec la même clé, pour qu'une
nouvelle version s'installe par-dessus la précédente. Cette clé n'est **pas**
celle des versions de distribution (lot D).

| Élément | Où |
| --- | --- |
| Clé (PKCS12, alias `safelink-dev`, RSA 4096) | Secret GitHub `SAFELINK_DEV_KEYSTORE_BASE64` (fichier encodé en base64) |
| Mot de passe | Secret GitHub `SAFELINK_DEV_KEYSTORE_PASSWORD` |
| Empreinte SHA-256 du certificat, publique | `tools/dev-signing-cert.sha256` |

- Gradle lit la clé dans `SAFELINK_DEV_KEYSTORE` et
  `SAFELINK_DEV_KEYSTORE_PASSWORD` ; sans ces variables (build local, CI des
  pull requests), il utilise la clé de débogage de la machine.
- `dev-apk.yml` vérifie que chaque APK porte l'empreinte de
  `tools/dev-signing-cert.sha256`. Si les secrets sont absents, il publie
  quand même, avec une signature temporaire annoncée en tête des notes de
  la pré-version (désinstallation nécessaire).
- Pour enregistrer les secrets : *Settings › Secrets and variables › Actions ›
  New repository secret*, une fois pour chacun des deux noms ci-dessus.
- Changer de clé oblige à désinstaller l'application sur chaque téléphone de
  test : ne le faire qu'en cas de compromission, et mettre à jour
  `tools/dev-signing-cert.sha256` dans le même commit.

## Mettre à jour Flutter

1. Modifier `.flutter-version` et `environment.flutter` dans
   `app/pubspec.yaml`.
2. Régénérer un projet témoin (`flutter create`) et reporter les versions
   d'AGP, Kotlin et Gradle du gabarit.
3. `flutter pub upgrade`, puis toute la séquence de vérification ci-dessus.
4. Mettre à jour ce tableau et le `CHANGELOG.md`.

## Signature des versions de distribution

À venir avec le lot D : génération du keystore sur votre machine, stockage
en secrets GitHub de l'environnement protégé `release`, vérification de la
signature dans `release.yml`. Le keystore et ses mots de passe ne doivent
jamais être versionnés ni envoyés dans un message.
