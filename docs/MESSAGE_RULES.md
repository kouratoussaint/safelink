# Règles d'analyse des messages

Dictionnaire : `fr-1.0.0` (`MessageDictionary.french`, moteur
`safelink_engine`). Tout se passe sur l'appareil : SafeLink ne lit jamais
les SMS, notifications ou conversations ; il n'analyse que le texte collé,
saisi ou partagé volontairement.

## Préparation du texte

- Version repliée pour la recherche : minuscules, sans accents,
  apostrophes, guillemets, tirets et espaces unifiés, caractères invisibles
  retirés. Chaque caractère garde sa position d'origine pour surligner
  l'extrait exact.
- Phrases et propositions ; passages cités (« … », “…”, "…", lignes
  commençant par `>`).
- Négations : « ne… jamais », « n'… pas », « aucun », « sans »… Les
  tournures qui renforcent un ordre (« n'hésitez pas », « ne tardez pas »)
  et la menace « si vous ne payez pas » ne sont pas des négations.
- Éléments repérés : liens (avec protocole, `www.`, domaines nus et formes
  déguisées `hxxp`, `[.]`, `(dot)`…), numéros de téléphone, codes USSD,
  montants en francs CFA.

## Indices

Aucun mot isolé ne vaut preuve : chaque règle exige une construction (verbe
et objet, paiement et but, menace et sujet) et écarte les tournures niées.
Un indice relevé seulement dans un passage cité descend au niveau faible.

| Code | Gravité | Catégorie | Ce qui est repéré |
| --- | --- | --- | --- |
| `MSG_CREDENTIALS_REQUEST` | forte | Identifiants ou code | Verbe de transmission (envoyer, communiquer, donner, transmettre…) et code, PIN, OTP, mot de passe. « Ne communiquez jamais votre code » est un conseil ; « si quelqu'un vous demande votre code » une mise en garde |
| `MSG_SECRET_ENTRY` | forte | Identifiants ou code | Saisir un PIN, un code secret, un mot de passe, un numéro de carte ou un CVV. Saisir un code à usage unique sur un site n'est pas un indice |
| `MSG_MISTAKEN_TRANSFER` | forte | Variante locale | Transfert « par erreur » avec demande de le renvoyer (moyenne sans demande) |
| `MSG_USSD_TRANSFER` | forte | Variante locale | Instruction de composer un code USSD contenant un numéro ou un montant (moyenne sans instruction). `*144#` seul n'est pas un indice |
| `MSG_PAYMENT_REQUEST` | moyenne | Paiement ou frais anticipés | Payer ou envoyer de l'argent avec des frais (dossier, déblocage, taxe, amende, caution…), un but (recevoir, débloquer, éviter…), un numéro destinataire ou une menace. Une facture, un reçu ou « sans frais » ne comptent pas |
| `MSG_PRIZE` | moyenne | Gain ou cadeau | « vous avez gagné » suivi d'un objet ou d'une somme, gagnant, tirage au sort, loterie, « doublez votre argent », somme « en attente »… |
| `MSG_ACCOUNT_THREAT` | moyenne | Menace de blocage | Compte, carte, ligne ou SIM qui « sera suspendu », « bloqué »… |
| `MSG_OFF_CHANNEL` | moyenne | Sortie du canal officiel | Inviter à écrire ou appeler sur WhatsApp, Telegram, en privé… |
| `MSG_LINK_BRAND_MISMATCH` | moyenne | Lien trompeur | Le message cite une marque de référence, le lien mène ailleurs que sur ses domaines officiels (un lien déguisé, qui ne se clique pas, est écarté) |
| `MSG_SELECTION` | faible | Gain ou cadeau | « vous avez été sélectionné », prêt ou subvention « accordé », offre d'emploi, recrutement |
| `MSG_IMPERSONATION` | faible | Usurpation déclarée | Service client, « votre banque », agent, administration, marque citée. Le nom cité n'est jamais tenu pour authentifié |
| `MSG_CALL_NUMBER` | faible | Sortie du canal officiel | Inviter à appeler ou contacter un numéro écrit dans le message |
| `MSG_LINK_ACTION` | faible | Lien trompeur | Demander d'agir sur un lien : cliquer, confirmer, réactiver, payer… |
| `MSG_URGENCY` | faible | Urgence ou pression | « urgent », « dernier délai », « sous 24 h », « aujourd'hui seulement »… |
| `MSG_DEFANGED_LINK` | information | Lien trompeur | Lien écrit sous forme déguisée ; il est analysé sous sa forme réelle |

Les liens repérés sont aussi analysés un par un selon
[URL_RULES.md](URL_RULES.md).

## Verdict du message

| Verdict | Condition |
| --- | --- |
| `HIGH_RISK_MESSAGE` (« Forts indices d'arnaque ») | Un indice fort, ou une demande de paiement avec un gain, un organisme cité, une urgence ou une menace de blocage |
| `SUSPICIOUS_MESSAGE` (« Message suspect ») | Un indice moyen, ou deux indices faibles ; citer un organisme ne compte pas ici, car presque tous les messages légitimes le font |
| `NO_OBVIOUS_SIGNALS` (« Aucun indice évident relevé ») | Texte en français, d'au moins trois mots, sans indice |
| `INCONCLUSIVE_MESSAGE` (« Analyse insuffisante ») | Texte trop court ou majoritairement dans une autre langue, sans indice |
| `INVALID_MESSAGE` (« Message non analysable ») | Texte vide ou de plus de 10 000 caractères (réglable) |

Les indices relevés seulement dans un passage cité comptent comme faibles
et n'entrent dans aucune combinaison forte. SafeLink n'affiche jamais
« Message authentique » ni « Information vraie ».

## Résultat combiné

Le texte et chaque lien (dix au plus) sont analysés séparément ; les deux
résultats restent visibles. Le niveau de synthèse est le plus sévère des
deux : un texte rassurant ne masque jamais un lien dangereux, et un lien sans
indice n'efface pas un texte suspect. Les gestes recommandés suivent les
indices relevés : ne communiquer aucun code, ne pas composer le code
indiqué, vérifier son solde dans l'application officielle, ne rien payer,
rester sur les canaux officiels, signaler et bloquer l'expéditeur.

## Évaluation

`data/corpus/messages.tsv` (CC0, messages inventés) est évalué à chaque
pull request par `packages/safelink_engine/tool/evaluate_messages.dart`. La
CI échoue si un message légitime est classé « Forts indices », si moins de
90 % des arnaques sont signalées ou si plus de 25 % des messages légitimes
le sont. Le rapport détaille les résultats par catégorie.

## Limites connues

- Français seulement ; les messages en anglais ou en langues nationales
  obtiennent « Analyse insuffisante » faute d'indice.
- Les mots déguisés (`c0de`, `p.i.n`) ne sont pas encore reconnus.
- Les règles repèrent des procédés courants ; une arnaque nouvelle peut
  n'en présenter aucun.
