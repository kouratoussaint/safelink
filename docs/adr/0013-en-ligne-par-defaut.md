# 0013 — Vérification en ligne activée par défaut

- Statut : accepté (27/11/2026, décision du porteur)
- Modifie : [0010](0010-verification-en-ligne.md) (consentement),
  [0011](0011-services-google.md), [0012](0012-liens-raccourcis.md)

## Contexte

La vérification en ligne (Quad9, Cloudflare, registre, Google, vraie
destination des liens raccourcis) donne l'essentiel du résultat : liste de
sites signalés, âge du site, photo de la page. Tant que l'utilisateur ne
l'avait pas acceptée, l'analyse se faisait seulement sur le téléphone. Le
porteur veut que l'analyse en ligne soit prioritaire.

## Décision

- La vérification en ligne est **activée dès l'installation**. Seul un
  refus enregistré la coupe (`online_checks_v2` = `disabled`) ; un refus
  déjà donné reste respecté.
- La dernière étape de la présentation l'annonce (« Vérification en ligne
  activée »), nomme les destinataires et ce qui leur est envoyé, et propose
  « Continuer » ou « Rester hors ligne ». Interrupteur dans les paramètres.
- La carte « Vérifier aussi en ligne ? » sous les résultats disparaît.
- Sans connexion, l'analyse sur le téléphone prend le relais ; un bandeau
  « Pas de connexion » le dit en haut du résultat, avec « Réessayer ».

## Conséquences

- Ce qui est envoyé ne change pas (ADR 0010 à 0012) : nom du site,
  empreintes partielles, lien à Google pour la photo, lien raccourci à son
  service ; jamais le texte d'un message.
- L'information remplace l'accord préalable : elle doit rester claire dans
  la présentation, les paramètres et la politique de confidentialité
  (lot D3).
