// Les motifs sont des expressions régulières coupées sur plusieurs lignes :
// les chaînes adjacentes s'y collent sans espace, volontairement.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:meta/meta.dart';

/// Catégorie d'indice dans le texte d'un message (cahier des charges,
/// F03bis), plus les variantes locales.
enum MessageSignalCategory {
  /// Demande d'identifiants, de code OTP ou PIN, de mot de passe.
  credentials,

  /// Paiement ou frais à avancer.
  payment,

  /// Gain, cadeau ou sélection inespérés.
  prize,

  /// Menace de blocage ou de suspension.
  accountThreat,

  /// Organisme, marque ou agent cité.
  impersonation,

  /// Incitation à quitter le canal officiel.
  offChannel,

  /// Urgence ou pression.
  urgency,

  /// Lien qui ne correspond pas à la marque citée, ou lien déguisé.
  deceptiveLink,

  /// Variante locale : transfert prétendument fait « par erreur ».
  mistakenTransfer,

  /// Variante locale : code USSD qui déclenche un transfert.
  ussdTransfer,
}

/// Expression du dictionnaire : motif sur le texte replié (minuscules,
/// sans accents, apostrophes droites).
@immutable
final class PhrasePattern {
  /// Crée une expression. Avec [addressed], l'expression ne compte que si
  /// la phrase s'adresse au destinataire (« vous », « votre », « tu »…) :
  /// « grande tombola de la paroisse » n'est pas une annonce de gain.
  new(this.id, String source, {this.addressed = false})
    : regex = RegExp(source);

  /// Identifiant stable, pour les tests et la documentation.
  final String id;

  /// Vrai si la phrase doit s'adresser au destinataire.
  final bool addressed;

  /// Motif compilé.
  final RegExp regex;
}

/// Dictionnaire versionné des expressions recherchées dans les messages.
///
/// Configurable : un autre dictionnaire peut être fourni aux règles. Aucune
/// expression ne vaut preuve à elle seule ; les règles combinent les
/// indices et écartent les tournures niées ou citées.
final class MessageDictionary {
  /// Crée un dictionnaire.
  new({
    required this.version,
    required this.transmissionVerbs,
    required this.entryVerbs,
    required this.secrets,
    required this.strongSecrets,
    required this.paymentVerbs,
    required this.paymentPurposes,
    required this.scamFees,
    required this.ordinaryFees,
    required this.prizes,
    required this.selections,
    required this.accountThreats,
    required this.impersonations,
    required this.messagingApps,
    required this.contactVerbs,
    required this.urgencies,
    required this.mistakenTransfers,
    required this.returnRequests,
    required this.dialVerbs,
    required this.linkActionVerbs,
  });

  /// Version du dictionnaire, citée dans les résultats.
  final String version;

  /// Verbes de transmission à une personne : envoyer, communiquer,
  /// donner…
  final String transmissionVerbs;

  /// Verbes de saisie : saisir, entrer, taper…
  final String entryVerbs;

  /// Secrets : code, PIN, OTP, mot de passe…
  final String secrets;

  /// Secrets qu'aucun service ne fait saisir dans un message : PIN, code
  /// secret, mot de passe, numéro de carte, CVV.
  final String strongSecrets;

  /// Verbes de paiement.
  final String paymentVerbs;

  /// Buts d'un paiement anticipé : recevoir, débloquer, retirer…
  final String paymentPurposes;

  /// Frais typiques des arnaques : dossier, déblocage, inscription…
  final String scamFees;

  /// Frais ordinaires (« frais de scolarité ») : une demande de paiement
  /// avec ces frais n'est qu'un indice faible, sauf combinée à un gain.
  final String ordinaryFees;

  /// Expressions de gain.
  final List<PhrasePattern> prizes;

  /// Sélection ou offre inespérée (indice faible).
  final List<PhrasePattern> selections;

  /// Menaces de blocage.
  final List<PhrasePattern> accountThreats;

  /// Organismes et agents cités.
  final List<PhrasePattern> impersonations;

  /// Messageries privées.
  final String messagingApps;

  /// Verbes de contact.
  final String contactVerbs;

  /// Expressions d'urgence.
  final List<PhrasePattern> urgencies;

  /// Transfert « par erreur ».
  final List<PhrasePattern> mistakenTransfers;

  /// Demandes de restitution.
  final String returnRequests;

  /// Verbes pour composer un code.
  final String dialVerbs;

  /// Verbes qui demandent d'agir sur un lien : cliquer, confirmer,
  /// réactiver…
  final String linkActionVerbs;

  /// Dictionnaire français du MVP.
  static final MessageDictionary french = MessageDictionary(
    version: 'fr-1.0.0',
    transmissionVerbs:
        r'(?:r?envoi\w*|r?envoy\w*|communiqu\w*|donn\w*|transmet\w*|'
        r'transmis|partag\w*|dict\w*|indiqu\w*|fourni\w*|remet\w*|'
        r'demand\w*|dis|dites|dire|file|filez|faire parvenir|repond\w*|'
        r'fai\w* parvenir)',
    entryVerbs:
        r'(?:saisi\w*|entre[rz]?|entrez|tape[rz]?|inscri\w*|'
        r'renseign\w*|rempli\w*|confirm\w*|valid\w*)',
    // « code » seul, sauf les codes qui ne donnent accès à rien d'important
    // (« code du wifi », « code promo », « code postal »…).
    secrets:
        "(?:codes?(?! (?:du |de la |de l'|d')?(?:wifi|wi-fi|porte|portail|"
        'cadenas|promo|promotionnel|postal|route|couleur|vestimentaire|'
        'source|qr|barre|article|civil|penal|travail|electoral|reduction|'
        'parrainage))|code secret|code pin|pin|otp|mots? de passe|mdp|'
        'identifiants?|numero de (?:votre |ta )?carte|cvv|cvc|'
        "code (?:de |d')(?:confirmation|validation|verification|retrait|"
        'securite|transaction|activation))',
    strongSecrets:
        '(?:code secret|code pin|pin|mots? de passe|mdp|'
        'numero de (?:votre |ta )?carte|cvv|cvc)',
    paymentVerbs:
        '(?:payez|payer|paye|payes|reglez|regler|regle|versez|verser|'
        'verse|deposez|deposer|depose|envoyez|envoyer|envoie|transferez|'
        'transferer|transfere|rechargez|recharger|recharge|achetez|'
        'acheter|achete|effectuez|effectuer|faites (?:un |le )?'
        '(?:depot|transfert|versement|paiement)|faire (?:un |le )?'
        '(?:depot|transfert|versement|paiement))',
    paymentPurposes:
        '(?:recevoir|debloquer|deblocage|retirer|valider|activer|obtenir|'
        'beneficier|toucher|recuperer|liberer|finaliser|confirmer|'
        "encaisser|eviter|(?:l'|le |la |les |votre |ton |vos )?"
        '(?:enregistrement|inscription|dossier|activation|validation|'
        'traitement|ouverture|liberation|deblocage|reception|remise))',
    scamFees:
        "(?:frais (?:de |d')(?:dossier|deblocage|inscription|douane|"
        'activation|traitement|enregistrement|validation|'
        'dedouanement|liberation|ouverture|livraison|reexpedition)|'
        'taxes?|amendes?|penalites?|caution|droits de douane)',
    ordinaryFees: "(?:frais (?:de |d')[a-z]+|cotisations?|contributions?)",
    prizes: [
      PhrasePattern(
        'won',
        // Un gain suivi d'un objet ou d'une somme : « tu as gagné le match »
        // ne compte pas.
        '(?<![a-z])(?:vous avez|tu as|vous etes|tu es) (?:ete )?'
            r'(?:gagne|remporte|beneficie)[^.!?\n]{0,40}?(?:\d|(?<![a-z])'
            '(?:lot|prix|cadeau|bonus|telephone|smartphone|iphone|samsung|'
            'tecno|ordinateur|tablette|moto|voiture|millions?|somme|argent|'
            'bourse|voyage|billet|recompense|gain|credit|unites|tirage))',
      ),
      PhrasePattern(
        'winner',
        '(?<![a-z])(?:gagnant|gagnante|gagnants)(?![a-z])',
        addressed: true,
      ),
      PhrasePattern(
        'draw',
        '(?<![a-z])(?:tirage au sort|tire au sort)(?![a-z])',
        addressed: true,
      ),
      PhrasePattern(
        'lottery',
        '(?<![a-z])(?:loterie|jackpot|tombola|jeu concours)(?![a-z])',
        addressed: true,
      ),
      PhrasePattern(
        'lucky',
        '(?<![a-z])(?:heureux|heureuse|grand) (?:gagnant|beneficiaire|elu)',
      ),
      PhrasePattern(
        'multiply',
        '(?<![a-z])(?:doublez|triplez|multipliez|doubler|tripler) '
            '(?:votre|ton|vos|tes|son) (?:argent|capital|mise|investissement|'
            'gain|solde)',
      ),
      PhrasePattern('earn', r'(?<![a-z])gagnez (?:jusqu.a |plus de )?\d'),
      PhrasePattern(
        'pending_money',
        '(?<![a-z])(?:argent|fonds|paiement|transfert|remboursement|gain|'
            r'somme|\d[\d .]* ?(?:f|fcfa|francs?))(?![a-z])[^.!?\n]{0,20}?'
            'en attente',
      ),
      PhrasePattern(
        'gift',
        '(?<![a-z])(?:votre|ton|un) (?:lot|prix|cadeau|gain|bonus) '
            "(?:de|d'une valeur|vous attend|t'attend)",
      ),
    ],
    selections: [
      PhrasePattern(
        'selected',
        '(?<![a-z])(?:vous avez|tu as) ete (?:selectionne|retenu|choisi)',
      ),
      PhrasePattern(
        'windfall',
        '(?<![a-z])(?:pret|credit|subvention|bourse|aide|financement|'
            r'indemnite)(?![a-z])[^.!?\n]{0,40}?(?<![a-z])(?:accorde|'
            'approuve|octroye|debloque|attribue)',
      ),
      PhrasePattern(
        'job',
        "(?<![a-z])(?:offre d'emploi|recrutement|recrute|embauche|"
            'poste a pourvoir)(?![a-z])',
      ),
    ],
    accountThreats: [
      PhrasePattern(
        'will_be_blocked',
        '(?<![a-z])(?:compte|carte|sim|ligne|numero|puce|abonnement|acces|'
            r'wallet|portefeuille)(?![a-z])[^.!?\n]{0,40}?(?<![a-z])'
            '(?:sera|va etre|vont etre|seront|est|a ete|sont|ont ete|'
            "risque d'etre|pourrait etre) (?:temporairement |"
            'definitivement |automatiquement )?(?:suspendu|bloque|desactive|'
            'ferme|supprime|resilie|gele|restreint|coupe|perdu)(?:es?|s)?',
      ),
      PhrasePattern(
        'suspension',
        '(?<![a-z])(?:suspension|blocage|desactivation|fermeture|'
            'resiliation|suppression)(?: definitive| immediate)? '
            "(?:de|du|d') ?(?:votre|ton|ta|vos)",
      ),
      PhrasePattern(
        'warning',
        '(?<![a-z])dernier (?:avertissement|rappel)(?![a-z])',
      ),
    ],
    impersonations: [
      PhrasePattern(
        'customer_service',
        '(?<![a-z])(?:service client|service clientele|service technique|'
            'support technique|equipe de securite|service de securite|'
            'cellule de securite)(?![a-z])',
      ),
      PhrasePattern(
        'agent',
        '(?<![a-z])(?:agent|conseiller|technicien|responsable|directeur) '
            "(?:de |d'|du )?(?:orange|moov|telecel|wave|coris|ecobank|"
            "la banque|votre banque|l'operateur|votre operateur|"
            '(?:service|cellule) )',
      ),
      PhrasePattern(
        'bank',
        '(?<![a-z])(?:votre|ta) (?:banque|operateur|agence)(?![a-z])',
      ),
      PhrasePattern(
        'authority',
        '(?<![a-z])(?:police|gendarmerie|douanes?|tresor public|'
            'impots|direction generale|ministere|presidence|interpol|'
            'tribunal|huissier|la poste|sonapost)(?![a-z])',
      ),
    ],
    messagingApps:
        '(?:whatsapp|telegram|messenger|signal|imo|viber|'
        'en prive|inbox|en mp|par mp|en dm)',
    contactVerbs:
        r'(?:ecri\w*|contact\w*|rejoi\w*|ajout\w*|parl\w*|discut\w*|'
        r'appel\w*|joign\w*|rappel\w*|ecrivez|ecris|bip\w*|'
        r'envoy\w* (?:un |moi un |nous un )?(?:message|sms|vocal))',
    urgencies: [
      PhrasePattern(
        'urgent',
        '(?<![a-z])(?:urgent|urgente|urgence|urgemment)(?![a-z])',
      ),
      PhrasePattern(
        'deadline',
        '(?<![a-z])(?:dernier delai|derniere chance|sans delai|vite|'
            'immediatement|au plus vite|des maintenant|tout de suite|'
            'dans les plus brefs delais)(?![a-z])',
      ),
      PhrasePattern(
        'countdown',
        r'(?<![a-z])(?:sous|dans les|dans|avant) \d{1,3} ?'
            '(?:h|heures?|minutes?|min|mn|jours?)(?![a-z])',
      ),
      PhrasePattern(
        'tonight',
        '(?<![a-z])(?:avant (?:ce soir|minuit|demain|la fin de la '
            "journee)|aujourd'hui (?:seulement|uniquement)|expire "
            "(?:aujourd'hui|ce soir|bientot|dans))(?![a-z])",
      ),
    ],
    mistakenTransfers: [
      PhrasePattern(
        'by_mistake',
        '(?<![a-z])(?:envoye|transfere|depose|verse|fait (?:un |le )?'
            '(?:depot|transfert)|recu|envoi|transfert|depot)(?![a-z])'
            r'[^.!?\n]{0,50}?(?<![a-z])par (?:erreur|megarde|accident)',
      ),
      PhrasePattern(
        'wrong_number',
        '(?<![a-z])(?:erreur de (?:numero|transfert|transaction|'
            'destinataire)|trompe(?:e)? de numero|mauvais numero)(?![a-z])',
      ),
    ],
    returnRequests:
        r'(?:r?envoy\w*|r?envoi\w*|rembours\w*|retourn\w*|restitu\w*|'
        r'rend\w*|revers\w*|renvoy\w*)',
    dialVerbs:
        r'(?:compos\w*|tape[rz]?|tapez|fai\w*|saisi\w*|entre[rz]?|'
        'lance[rz]?|valide[rz]?)',
    linkActionVerbs:
        '(?:cliquez|clique|cliquer|confirmez|validez|connectez-vous|'
        'connecte-toi|mettez a jour|verifiez|reactivez|suivez|'
        'rendez-vous|accedez|recuperez|reclamez|payez|inscrivez-vous|'
        'telechargez|installez|ouvrez|activez|completez|renseignez)',
  );
}
