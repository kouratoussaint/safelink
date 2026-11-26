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
> **État du projet : en développement (lot A, fondations).** L'analyse des
> liens et des messages n'est pas encore disponible. Aucune version n'est
> publiée pour le grand public ; la première pré-version installable est
> prévue à la fin du lot D. Aucune vérification n'est simulée en attendant.

## Ce que fait SafeLink, et ce qu'il ne fait pas

| SafeLink fera | SafeLink ne fera jamais |
| --- | --- |
| Analyser un lien collé, saisi, partagé ou lu dans un QR code | Ouvrir automatiquement un lien analysé, même pour le tester |
| Analyser le texte d'un message que vous lui transmettez | Lire vos SMS, notifications, e-mails ou conversations |
| Expliquer chaque indice relevé et les limites de l'analyse | Affirmer qu'un lien est « 100 % sûr » ou qu'un message est authentique |
| Fonctionner hors connexion pour l'analyse locale | Envoyer vos messages à un serveur ou à une IA distante |
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

SafeLink ne demande aucune permission Android à ce stade. La caméra ne sera
demandée qu'au moment de scanner un QR code. L'accès à Internet ne sera
ajouté que si une source de réputation est autorisée, et l'envoi de données
à un tiers ne se fera jamais sans votre accord explicite. Les sauvegardes
cloud de l'application sont désactivées.

## Contribuer

Les contributions sont bienvenues : voir [`CONTRIBUTING.md`](CONTRIBUTING.md).
Pour une faille de sécurité, suivez [`SECURITY.md`](SECURITY.md) et
n'ouvrez pas d'issue publique.

## Licence

Code sous licence [GNU GPL v3.0 ou ultérieure](LICENSE) : toute version
modifiée et redistribuée de SafeLink doit rester libre. Polices Poppins et
Inter sous SIL Open Font License 1.1.
