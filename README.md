<p align="center">
  <img src="docs/brand/safelink_icon.svg" alt="Logo SafeLink : bouclier et maillon de chaîne" width="96">
</p>

<h1 align="center">SafeLink</h1>
<p align="center"><strong>Vérifiez avant de cliquer.</strong></p>

<p align="center">
  <a href="https://github.com/kouratoussaint/safelink/actions/workflows/ci.yml"><img src="https://github.com/kouratoussaint/safelink/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0--or--later-blue" alt="Licence GPL-3.0-or-later"></a>
</p>

SafeLink est une application Android **gratuite, sans publicité, sans compte
et sans collecte de données** qui aide à repérer les tentatives de fraude,
d'hameçonnage et de manipulation dans les **liens** et les **messages** que
vous choisissez de lui soumettre. Elle explique en français simple ce qu'elle
a vérifié, ce qu'elle ne sait pas et les précautions à prendre.

Marché initial : Burkina Faso, puis Afrique francophone.

> [!IMPORTANT]
> **État du projet : en développement (lot D en cours).** L'application
> analyse les liens ([règles](docs/URL_RULES.md)) et les messages
> ([règles](docs/MESSAGE_RULES.md)) sur le téléphone et, si vous
> l'acceptez, vérifie en ligne le nom des sites
> ([ADR 0010](docs/adr/0010-verification-en-ligne.md)). Aucune version
> n'est publiée pour le grand public ; la première pré-version est prévue à
> la fin du lot D. Aucune vérification n'est simulée.

## Ce que fait SafeLink, et ce qu'il ne fait pas

| SafeLink fera | SafeLink ne fera jamais |
| --- | --- |
| Analyser un lien collé, saisi, partagé ou lu dans un QR code | Ouvrir automatiquement un lien analysé, même pour le tester |
| Analyser le texte d'un message que vous lui transmettez | Lire vos SMS, notifications, e-mails ou conversations |
| Expliquer chaque indice relevé et les limites de l'analyse | Affirmer qu'un lien est « 100 % sûr » ou qu'un message est authentique |
| Fonctionner hors connexion pour l'analyse locale, et vérifier en ligne le seul nom des sites si vous l'acceptez | Envoyer vos messages ou vos liens complets à un serveur ou à une IA distante |
| Conserver un historique local facultatif, supprimable | Afficher de la publicité ou vendre des données |

Les images, vidéos et documents seront étudiés dans des versions ultérieures.

## Limites de l'analyse

Un résultat sans alerte **ne prouve pas** qu'un lien ou un message est sûr :
une arnaque nouvelle ou bien rédigée peut échapper aux règles, et un message
légitime peut contenir des formules qui ressemblent à une arnaque. SafeLink
est une aide à la décision, pas une garantie, ni une preuve juridique.

## Compiler et tester

Prérequis : Flutter **3.50.1** (voir [`.flutter-version`](.flutter-version)),
JDK 17 ou plus (21 recommandé) et le SDK Android 36. Le détail, y compris
l'installation, est dans [`docs/BUILD.md`](docs/BUILD.md).

```bash
git clone https://github.com/kouratoussaint/safelink.git
cd safelink

# Moteur de détection (Dart pur)
cd packages/safelink_engine
dart pub get --enforce-lockfile
dart test
cd ../..

# Application
cd app
flutter pub get --enforce-lockfile
flutter test
flutter build apk --debug
# APK : app/build/app/outputs/flutter-apk/app-debug.apk
```

## Versions de développement

À chaque mise à jour de `main` ou d'une branche de lot, le workflow
[`dev-apk.yml`](.github/workflows/dev-apk.yml) publie les APK optimisés
(environ 20 Mo) dans une
[pré-version GitHub](https://github.com/kouratoussaint/safelink/releases)
nommée `dev-<révision>`, téléchargeable sans compte. Ces versions servent aux
essais et ne doivent pas être diffusées au public. Elles sont toutes signées
avec la même clé de développement : chaque nouvelle version s'installe
par-dessus la précédente. Les cinq dernières sont conservées.

## Organisation du dépôt

```text
app/                       Application Flutter (Android)
packages/safelink_engine/  Moteur de détection, Dart pur, sans réseau
docs/                      Architecture, compilation, décisions (adr/), sources
tools/                     Scripts : icônes, couverture, permissions
.github/                   CI, Dependabot, modèles d'issues
```

Voir [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) et
[`docs/adr/`](docs/adr/).

## Confidentialité

La permission Android utilisée par défaut est l'accès à Internet (la bulle
flottante, optionnelle, demande en plus « Afficher par-dessus d'autres
applis » et, sur Android 13 et suivants, les notifications,
[ADR 0014](docs/adr/0014-raccourcis-systeme.md) et
[0015](docs/adr/0015-panneau-rapide.md)). Internet sert
uniquement à la vérification en ligne, activée par défaut et désactivable dans les
paramètres ([ADR 0013](docs/adr/0013-en-ligne-par-defaut.md)) : le nom du site
(`exemple.com`) est envoyé, en HTTPS, à Quad9 et Cloudflare et au registre
du domaine ; Google Safe Browsing ne reçoit que des empreintes partielles ;
Google reçoit le lien pour photographier la page, sauf s'il contient un
code personnel ([ADR 0011](docs/adr/0011-services-google.md)) ; un lien
raccourci est envoyé à son service pour connaître sa vraie destination,
sans l'ouvrir ([ADR 0012](docs/adr/0012-liens-raccourcis.md)). Détail
complet : [docs/CONFIDENTIALITE.md](docs/CONFIDENTIALITE.md). Le texte
d'un message n'est jamais envoyé ; un texte partagé vers SafeLink est
traité comme un texte collé. La caméra ne
sera demandée qu'au moment de scanner un QR code. Pas de compte, pas de
publicité, pas de mesure d'audience. Les sauvegardes cloud de
l'application sont désactivées et l'historique, facultatif, est chiffré.

## Contribuer

Les contributions sont bienvenues : voir [`CONTRIBUTING.md`](CONTRIBUTING.md).
Pour une faille de sécurité, suivez [`SECURITY.md`](SECURITY.md) et
n'ouvrez pas d'issue publique.

## Licence

Code sous licence [GNU GPL v3.0 ou ultérieure](LICENSE) : toute version
modifiée et redistribuée de SafeLink doit rester libre. Polices Poppins et
Inter sous SIL Open Font License 1.1.
