# 0008 — Règles heuristiques des liens et verdict sans réputation

- Statut : accepté

## Contexte

Le cahier des charges fixe les principaux indices de l'analyse locale des
liens et leur gravité, et soumet à décision le signalement des liens vers
un fichier `.apk`. Sans source de réputation autorisée (ADR 0005), le
verdict repose sur ces seuls indices, qui ne prouvent jamais un danger.

## Décision

- Les indices et leurs gravités sont ceux de
  [docs/URL_RULES.md](../URL_RULES.md), qui fait référence.
- Un lien vers un fichier `.apk`, `.apks` ou `.xapk` produit un indice de
  gravité moyenne : au Burkina Faso, les fausses applications d'argent
  mobile circulent par ce moyen, et une application légitime s'installe
  normalement depuis le Play Store. L'indice n'empêche rien : il explique.
- Deux indices sont ajoutés à la liste du cahier des charges, avec la même
  prudence : mots d'appât dans le nom enregistré (moyen) et mélange
  d'alphabets sans marque reconnue (moyen).
- `SUSPICIOUS` dès un indice fort ou deux moyens ; `KNOWN_THREAT`
  seulement sur correspondance avec une liste de réputation de moins de
  7 jours. Les indices faibles et informatifs ne comptent pas.
- Un domaine officiel d'une marque de référence ne produit aucun indice
  favorable et ne change pas le verdict.

## Conséquences

Sans source de réputation, le meilleur verdict possible est
`INCONCLUSIVE` (« Vérification de réputation non disponible »). Le corpus
annoté et ses seuils bloquants en CI protègent contre les fausses alertes
lorsque les règles évoluent ; toute nouvelle règle s'accompagne de cas
annotés, légitimes et frauduleux.
