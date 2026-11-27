# 0004 — Partage Android entrant par canal Kotlin interne

- Statut : accepté (lot E1, 27/11/2026)

## Contexte

SafeLink doit recevoir du texte partagé (`ACTION_SEND`, `text/plain`), au
démarrage à froid comme à chaud, sans permission ni accès aux fichiers.
Le public visé lit peu : « Partager → SafeLink » évite de copier, changer
d'application et coller.

## Décision

Un canal de plateforme Kotlin dans `MainActivity`
(`com.fasosoft.safelink/share`), limité à `text/plain`, sans dépendance.

- **Côté Android**, l'activité ne fait que transmettre : type annoncé,
  texte (borné à 100 000 caractères, avec un drapeau « coupé »), présence
  de fichiers, contenu illisible. Elle garde le partage jusqu'à ce que
  l'interface le prenne (`take`) et la prévient (`available`) quand un
  nouveau arrive : rien n'est perdu, même reçu pendant la présentation de
  première ouverture. Une activité recréée ou rouverte depuis les
  applications récentes ne relance pas l'analyse. Aucun fichier n'est
  ouvert ; le texte n'est jamais écrit dans les journaux.
- **Côté Dart**, toutes les décisions sont prises et testées
  (`features/share/`) :
  - un lien seul (navigateur, YouTube) est analysé tout de suite comme un
    lien ;
  - un texte sans lien est analysé tout de suite comme un message ;
  - un texte avec des liens propose « Tout le message » ou « Le lien
    seulement », puis le choix du lien s'il y en a plusieurs (liens
    masqués, domaine enregistré en gras) ;
  - un texte trop long ou accompagné d'un fichier passe par le même écran,
    avec l'avertissement (« seul le début », « le fichier n'est pas
    ouvert ») ;
  - des fichiers seuls ou un partage vide sont refusés avec une
    explication en pictogrammes : « Pas encore possible », que faire à la
    place.
- Le partage s'ouvre toujours depuis l'Accueil : Retour y ramène.
- SafeLink n'apparaît que pour le texte dans le menu « Partager » : il ne
  propose pas les photos et vidéos tant qu'il ne sait pas les vérifier.

Repli possible : `receive_sharing_intent` (Apache-2.0).

## Conséquences

Aucune dépendance ni permission supplémentaire, périmètre strictement
limité au texte. La logique est couverte par les tests Dart ; le canal
Kotlin le sera sur émulateur par `adb shell am start` (#29).
