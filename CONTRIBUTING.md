# Contribuer à SafeLink

Merci de votre intérêt. SafeLink protège des personnes qui ne sont pas
techniciennes : la prudence des verdicts et le respect de la vie privée
passent avant toute fonctionnalité.

## Principes non négociables

1. Gratuité totale, sans publicité, sans compte, sans mesure d'audience.
2. Aucun verdict ne qualifie un lien de « sûr » ni un message
   d'« authentique » ; chaque résultat dit ce qui n'a pas été vérifié.
3. Aucune lecture automatique de SMS, notifications ou conversations.
4. Aucun lien analysé n'est ouvert automatiquement, ni dans une WebView.
5. Aucun secret, jeton ou donnée personnelle dans le dépôt.
6. Toute nouveauté qui touche au périmètre, aux permissions, au coût, à la
   confidentialité ou à l'architecture passe d'abord par une ADR
   (`docs/adr/`) validée par le mainteneur.

## Mettre en place l'environnement

Suivez [`docs/BUILD.md`](docs/BUILD.md). En résumé : Flutter 3.50.1, JDK 17+
et SDK Android 36.

## Conventions

- **Langue.** Textes visibles et documentation en français ; identifiants
  du code en anglais ; commentaires de documentation en français.
- **Textes de l'interface.** Uniquement dans `app/lib/l10n/app_fr.arb`.
- **Style.** `dart format` et les règles `very_good_analysis` ;
  `flutter analyze --fatal-infos` doit être vierge.
- **Tests.** Toute règle de détection arrive avec ses tests, y compris des
  cas légitimes qui ne doivent pas déclencher d'alerte. Le moteur garde une
  couverture d'au moins 90 %.
- **Données de test.** Uniquement des exemples synthétiques, écrits pour
  l'occasion et publiés sous CC0. Jamais de message réel, même anonymisé
  sommairement, ni de vraie URL contenant un jeton.
- **Dépendances.** Licence compatible GPL-3.0-or-later, maintenance active,
  aucune télémétrie. Justifier tout ajout dans la pull request.
- **Couleurs.** Passer par les jetons du thème (`AppTheme`,
  `SafeLinkColors`), dont les contrastes sont vérifiés par les tests.

## Proposer une modification

1. Ouvrez ou choisissez une issue.
2. Créez une branche depuis `main`.
3. Vérifiez en local :

   ```bash
   (cd packages/safelink_engine && dart format . && dart analyze --fatal-infos && dart test)
   (cd app && dart format lib test && flutter analyze --fatal-infos && flutter test)
   ```

4. Ouvrez une pull request et remplissez la liste de vérification. La CI et
   la revue du mainteneur sont obligatoires avant fusion.

Les messages de commit décrivent le pourquoi, en français ou en anglais.

## Signaler un résultat d'analyse contestable

Utilisez le modèle « Résultat d'analyse contestable » et anonymisez le
contenu : noms, numéros, montants personnels, codes et jetons remplacés par
des valeurs fictives.
