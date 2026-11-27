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
| `MSG_PAYMENT_REQUEST` | moyenne | Paiement ou frais anticipés | Payer ou envoyer de l'argent avec des frais (dossier, déblocage…), un but (recevoir, débloquer…), un destinataire ou une menace. Une facture ou un reçu sans demande ne compte pas |
| `MSG_PRIZE` | moyenne | Gain ou cadeau | « vous avez gagné », gagnant, tirage au sort, loterie… |
| `MSG_ACCOUNT_THREAT` | moyenne | Menace de blocage | Compte, carte, ligne ou SIM qui « sera suspendu », « bloqué »… |
| `MSG_OFF_CHANNEL` | moyenne | Sortie du canal officiel | Inviter à écrire ou appeler sur WhatsApp, Telegram, en privé… |
| `MSG_LINK_BRAND_MISMATCH` | moyenne | Lien trompeur | Le message cite une marque de référence, le lien mène ailleurs que sur ses domaines officiels |
| `MSG_SELECTION` | faible | Gain ou cadeau | « vous avez été sélectionné », offre d'emploi, recrutement |
| `MSG_IMPERSONATION` | faible | Usurpation déclarée | Service client, « votre banque », agent, administration, marque citée. Le nom cité n'est jamais tenu pour authentifié |
| `MSG_CALL_NUMBER` | faible | Sortie du canal officiel | Inviter à appeler ou contacter un numéro écrit dans le message |
| `MSG_URGENCY` | faible | Urgence ou pression | « urgent », « dernier délai », « sous 24 h », « aujourd'hui seulement »… |
| `MSG_DEFANGED_LINK` | information | Lien trompeur | Lien écrit sous forme déguisée ; il est analysé sous sa forme réelle |

Les liens repérés sont aussi analysés un par un selon
[URL_RULES.md](URL_RULES.md).

## Limites connues

- Français seulement ; les messages en anglais ou en langues nationales
  obtiennent « Analyse insuffisante » faute d'indice.
- Les mots déguisés (`c0de`, `p.i.n`) ne sont pas encore reconnus.
- Les règles repèrent des procédés courants ; une arnaque nouvelle peut
  n'en présenter aucun.
