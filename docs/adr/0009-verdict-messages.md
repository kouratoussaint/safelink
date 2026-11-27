# 0009 — Verdict des messages et résultat combiné

- Statut : accepté

## Contexte

Le cahier des charges (F03bis, F06) et le plan fixent cinq verdicts de
message, huit catégories d'indices et la règle « le bandeau prend le niveau
le plus sévère ». Plusieurs points restaient à trancher pour éviter les
fausses alertes sur les messages légitimes, très nombreux à citer un
opérateur ou une banque.

## Décision

- `HIGH_RISK_MESSAGE` : un indice fort (demande de code, saisie d'un
  secret, transfert « par erreur » à renvoyer, code USSD de transfert), ou
  une demande de paiement combinée à un gain, un organisme cité, une
  urgence ou une **menace de blocage** (ajoutée : c'est une forme de
  pression).
- `SUSPICIOUS_MESSAGE` : un indice moyen ou deux faibles. **Citer un
  organisme ne compte pas parmi les deux faibles** : presque tous les
  messages légitimes le font ; il ne compte qu'avec un paiement.
- Un indice relevé seulement dans un passage cité (guillemets, lignes `>`)
  descend au niveau faible et n'entre dans aucune combinaison forte.
- Une demande de paiement de frais ordinaires (« frais de scolarité ») est
  un indice faible ; elle devient forte avec un gain ou une sélection
  (faux recrutement).
- Un lien déguisé (`hxxp`, `[.]`) ne produit pas d'indice de lien trompeur :
  il ne se clique pas et vient en général d'une mise en garde.
- `INCONCLUSIVE_MESSAGE` : sans indice, texte de moins de trois mots ou
  dont moins de 20 % des mots sont des mots français fréquents ; les liens
  ne comptent pas comme mots. Un indice relevé l'emporte sur la longueur.
- Plafond : 10 000 caractères (réglable) ; dix liens analysés au plus par
  message, la limite étant signalée au-delà.
- Résultat combiné : analyses du texte et des liens séparées, niveau de
  synthèse le plus sévère ; gestes du lien en premier quand il est plus
  risqué que le texte.

## Conséquences

Sur le corpus de 184 messages inventés (CC0), dont 32 rédigés après la mise
au point des règles : 100 % des arnaques signalées, aucun message légitime
en « Forts indices », 2,5 % des messages légitimes signalés. Sur les 32
messages de validation, avant correction : 93,8 % des arnaques signalées,
aucun légitime en « Forts indices ». Les seuils sont bloquants en CI. Ces
chiffres mesurent un corpus rédigé par le projet : ils ne garantissent pas
le comportement sur de vrais messages, qui restent la limite affichée.
