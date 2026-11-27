import 'package:meta/meta.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Portion d'un message, en positions du texte d'origine (unités UTF-16,
/// début inclus, fin exclue), pour surligner un extrait à l'écran.
@immutable
final class MessageSpan {
  /// Crée une portion. Lève une [ArgumentError] si les bornes sont
  /// incohérentes.
  new(this.start, this.end) {
    if (start < 0 || end < start) {
      throw ArgumentError('Portion invalide : $start–$end');
    }
  }

  /// Début, inclus.
  final int start;

  /// Fin, exclue.
  final int end;

  /// Longueur en unités UTF-16.
  int get length => end - start;

  /// Vrai si [other] est entièrement contenue dans cette portion.
  bool contains(MessageSpan other) => other.start >= start && other.end <= end;

  /// Vrai si les deux portions se chevauchent.
  bool overlaps(MessageSpan other) => other.start < end && start < other.end;

  /// Texte de la portion dans [text].
  String of(String text) => text.substring(start, end);

  @override
  bool operator ==(Object other) =>
      other is MessageSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MessageSpan($start, $end)';
}

/// Texte « replié » pour la recherche : minuscules, sans accents,
/// apostrophes, guillemets, tirets et espaces unifiés, caractères invisibles
/// retirés. Chaque caractère replié garde la position de son caractère
/// d'origine, pour revenir au texte tel qu'il a été écrit.
final class FoldedText {
  /// Replie [original].
  factory(String original) {
    final buffer = StringBuffer();
    final starts = <int>[];
    final ends = <int>[];
    var index = 0;
    for (final rune in original.runes) {
      final width = rune > 0xFFFF ? 2 : 1;
      final folded = foldRune(rune);
      for (final unit in folded.codeUnits) {
        buffer.writeCharCode(unit);
        starts.add(index);
        ends.add(index + width);
      }
      index += width;
    }
    return FoldedText._(original, buffer.toString(), starts, ends);
  }
  new _(this.original, this.text, this._starts, this._ends);

  /// Texte d'origine.
  final String original;

  /// Texte replié.
  final String text;

  final List<int> _starts;
  final List<int> _ends;

  /// Portion d'origine correspondant à la portion repliée
  /// [foldedStart]–[foldedEnd].
  MessageSpan toOriginal(int foldedStart, int foldedEnd) {
    if (foldedStart >= foldedEnd) {
      final position = foldedStart < _starts.length
          ? _starts[foldedStart]
          : original.length;
      return MessageSpan(position, position);
    }
    return MessageSpan(_starts[foldedStart], _ends[foldedEnd - 1]);
  }

  /// Position repliée du premier caractère issu de la position d'origine
  /// [originalIndex] ou situé après elle.
  int toFolded(int originalIndex) {
    var low = 0;
    var high = _starts.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_starts[mid] < originalIndex) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static final _combiningMark = RegExp(
    '[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]',
  );

  /// Forme repliée d'un caractère ; vide pour un caractère invisible.
  static String foldRune(int rune) {
    if (rune < 0x80) {
      return rune >= 0x41 && rune <= 0x5A
          ? String.fromCharCode(rune + 0x20)
          : String.fromCharCode(rune);
    }
    switch (rune) {
      case 0x00AD || 0x200B || 0x200C || 0x200D || 0x2060 || 0xFEFF:
      case 0x200E || 0x200F || 0x061C:
      case >= 0x202A && <= 0x202E:
      case >= 0x2066 && <= 0x2069:
        return '';
      case 0x2018 || 0x2019 || 0x201B || 0x02BC || 0x00B4 || 0x2032:
        return "'";
      case 0x00AB || 0x00BB || 0x201C || 0x201D || 0x201E || 0x201F:
      case 0x2039 || 0x203A:
        return '"';
      case >= 0x2010 && <= 0x2015:
      case 0x2212:
        return '-';
      case 0x00A0 || 0x202F || 0x205F || 0x3000:
      case >= 0x2000 && <= 0x200A:
        return ' ';
      case 0x0153 || 0x0152:
        return 'oe';
      case 0x00E6 || 0x00C6:
        return 'ae';
      case 0x00DF:
        return 'ss';
    }
    final decomposed = unorm.nfkd(String.fromCharCode(rune));
    return decomposed.replaceAll(_combiningMark, '').toLowerCase();
  }
}

/// Évaluation rudimentaire de la langue : part des mots-outils français.
@immutable
final class LanguageAssessment {
  /// Crée une évaluation.
  const new({required this.wordCount, required this.frenchWordCount});

  /// Nombre de mots.
  final int wordCount;

  /// Nombre de mots-outils ou d'abréviations françaises reconnus.
  final int frenchWordCount;

  /// Part des mots reconnus comme français (0 si aucun mot).
  double get frenchRatio => wordCount == 0 ? 0 : frenchWordCount / wordCount;
}

/// Message préparé pour l'analyse, sur l'appareil, sans en changer le sens.
final class PreparedMessage {
  new _({
    required this.folded,
    required List<MessageSpan> sentences,
    required List<MessageSpan> quotations,
    required this.language,
  }) : sentences = List.unmodifiable(sentences),
       quotations = List.unmodifiable(quotations);

  /// Texte replié et correspondance des positions.
  final FoldedText folded;

  /// Phrases, en positions repliées.
  final List<MessageSpan> sentences;

  /// Passages cités (entre guillemets ou lignes commençant par « > »), en
  /// positions repliées.
  final List<MessageSpan> quotations;

  /// Évaluation de la langue.
  final LanguageAssessment language;

  /// Texte d'origine.
  String get original => folded.original;

  /// Texte replié.
  String get text => folded.text;

  /// Vrai si la portion repliée commence dans un passage cité.
  bool isQuoted(MessageSpan foldedSpan) => quotations.any(
    (q) => foldedSpan.start >= q.start && foldedSpan.start < q.end,
  );

  /// Phrase contenant la position repliée [position].
  MessageSpan sentenceAt(int position) => sentences.firstWhere(
    (s) => position >= s.start && position < s.end,
    orElse: () => MessageSpan(0, text.length),
  );

  /// Début de la proposition contenant la position repliée [position] :
  /// après la dernière ponctuation forte, virgule, point-virgule,
  /// deux-points ou parenthèse de la phrase.
  int clauseStart(int position) {
    final sentence = sentenceAt(position);
    for (var i = position - 1; i >= sentence.start; i--) {
      if (_clauseBreaks.contains(text.codeUnitAt(i))) return i + 1;
    }
    return sentence.start;
  }

  static final Set<int> _clauseBreaks = ',;:()\n'.codeUnits.toSet();

  static final _negation = RegExp(
    // « n' » est suivi d'une lettre (« n'envoyez ») ; les autres mots sont
    // entiers. « sans » n'est pas retenu : « prêt sans intérêt » n'annule
    // rien ; « sans frais » est traité par la règle de paiement.
    "(?<![a-z])(?:n'|(?:ne|jamais|aucun|aucune|nul|nulle|pas|rien|ni)"
    '(?![a-z]))',
  );

  /// Tournures négatives qui renforcent un ordre au lieu de l'annuler.
  static final _emphaticNegation = RegExp(
    r"n'(oubliez|oublie|hesitez|hesite)\s+pas|ne\s+(tardez|tarde|manquez|"
    r'manque|ratez|rate)\s+pas',
  );

  /// Vrai si la portion repliée [foldedSpan] est niée dans sa proposition :
  /// « ne communiquez jamais votre code ». Les tournures comme « n'hésitez
  /// pas » ou « si vous ne payez pas » ne comptent pas comme négations.
  bool isNegated(MessageSpan foldedSpan) {
    final start = clauseStart(foldedSpan.start);
    var clause = text.substring(start, foldedSpan.end);
    clause = clause.replaceAll(_emphaticNegation, ' ');
    if (RegExp(r'(?<![a-z])(si|sinon)\s+(vous|tu)\s+n').hasMatch(clause)) {
      return false;
    }
    return _negation.hasMatch(clause);
  }
}

/// Prépare un message : repli, phrases, citations, langue.
abstract final class MessagePreprocessor {
  /// Mots fréquents du français écrit, y compris en style SMS, après repli
  /// (sans accents) ; seuls les mots d'au moins deux lettres comptent.
  static const frenchWords = {
    'agence',
    'alors',
    'ami',
    'amis',
    'annee',
    'ans',
    'appel',
    'appeler',
    'appelez',
    'appels',
    'apres',
    'argent',
    'arnaque',
    'arrive',
    'arrivee',
    'attention',
    'au',
    'aujourd',
    'aussi',
    'aux',
    'avant',
    'avec',
    'avez',
    'avoir',
    'banque',
    'beaucoup',
    'bien',
    'bjr',
    'bon',
    'bonjour',
    'bonne',
    'bonsoir',
    'bonus',
    'boutique',
    'bsr',
    'bureau',
    'car',
    'carte',
    'ce',
    'ces',
    'cette',
    'chez',
    'client',
    'clients',
    'cliquer',
    'cliquez',
    'code',
    'codes',
    'colis',
    'commande',
    'comme',
    'compte',
    'comptes',
    'confirmer',
    'confirmez',
    'credit',
    'credite',
    'cv',
    'dans',
    'de',
    'deja',
    'demain',
    'demande',
    'demander',
    'demandera',
    'depot',
    'depuis',
    'des',
    'desole',
    'devez',
    'dieu',
    'dimanche',
    'disponible',
    'dois',
    'donc',
    'du',
    'ecole',
    'effectue',
    'eleves',
    'elle',
    'elles',
    'en',
    'encore',
    'entre',
    'envoie',
    'envoyer',
    'envoyez',
    'escroc',
    'est',
    'et',
    'etes',
    'etre',
    'excusez',
    'faire',
    'fait',
    'faites',
    'famille',
    'fcfa',
    'fete',
    'fois',
    'forfait',
    'frais',
    'francs',
    'frere',
    'grace',
    'heure',
    'heures',
    'hier',
    'hui',
    'ici',
    'il',
    'ils',
    'information',
    'informations',
    'internet',
    'jamais',
    'je',
    'jeudi',
    'jour',
    'jours',
    'ke',
    'koi',
    'la',
    'le',
    'les',
    'leur',
    'leurs',
    'lien',
    'livraison',
    'livre',
    'lui',
    'lundi',
    'ma',
    'mais',
    'maman',
    'marche',
    'mardi',
    'matin',
    'me',
    'merci',
    'mercredi',
    'mes',
    'message',
    'messages',
    'minutes',
    'moi',
    'mois',
    'mon',
    'montant',
    'mot',
    'ne',
    'non',
    'nos',
    'notre',
    'nous',
    'nouvelle',
    'nouvelles',
    'numero',
    'numeros',
    'offre',
    'offres',
    'on',
    'operation',
    'ou',
    'oui',
    'paiement',
    'papa',
    'par',
    'pardon',
    'parents',
    'pas',
    'passe',
    'payer',
    'payez',
    'pendant',
    'personne',
    'peut',
    'pk',
    'plus',
    'pour',
    'pouvez',
    'promotion',
    'prudent',
    'prudents',
    'qu',
    'quand',
    'que',
    'qui',
    'reception',
    'recevoir',
    'recharge',
    'recharges',
    'recu',
    'rendez',
    'repondre',
    'reponse',
    'resultats',
    'retard',
    'retrait',
    'reunion',
    'reussi',
    'rien',
    'sa',
    'samedi',
    'sans',
    'se',
    'secret',
    'semaine',
    'service',
    'services',
    'ses',
    'si',
    'site',
    'slt',
    'sms',
    'soeur',
    'soir',
    'solde',
    'somme',
    'son',
    'sont',
    'sous',
    'stp',
    'sur',
    'svp',
    'ta',
    'tata',
    'te',
    'tes',
    'toi',
    'ton',
    'tonton',
    'toujours',
    'tous',
    'tout',
    'toute',
    'toutes',
    'transaction',
    'transfert',
    'transferts',
    'travail',
    'tres',
    'tu',
    'un',
    'une',
    'valider',
    'validez',
    'vendredi',
    'vers',
    'veuillez',
    'vigilant',
    'voici',
    'voila',
    'vos',
    'votre',
    'vous',
  };

  static final int _quote = '"'.codeUnitAt(0);
  static final _word = RegExp('[a-z]+');

  /// Prépare [original].
  static PreparedMessage prepare(String original) {
    final folded = FoldedText(original);
    final text = folded.text;
    return PreparedMessage._(
      folded: folded,
      sentences: _sentences(text),
      quotations: _quotations(text),
      language: _language(text),
    );
  }

  static List<MessageSpan> _sentences(String text) {
    final sentences = <MessageSpan>[];
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final endsSentence =
          c == '\n' ||
          ((c == '.' || c == '!' || c == '?') &&
              (i + 1 == text.length ||
                  text[i + 1] == ' ' ||
                  text[i + 1] == '\n'));
      if (endsSentence) {
        if (i + 1 > start) sentences.add(MessageSpan(start, i + 1));
        start = i + 1;
      }
    }
    if (start < text.length) sentences.add(MessageSpan(start, text.length));
    return sentences;
  }

  static List<MessageSpan> _quotations(String text) {
    final quotations = <MessageSpan>[];
    int? open;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) != _quote) continue;
      if (open == null) {
        open = i;
      } else {
        quotations.add(MessageSpan(open, i + 1));
        open = null;
      }
    }
    var lineStart = 0;
    for (final line in text.split('\n')) {
      if (line.trimLeft().startsWith('>')) {
        quotations.add(MessageSpan(lineStart, lineStart + line.length));
      }
      lineStart += line.length + 1;
    }
    quotations.sort((a, b) => a.start.compareTo(b.start));
    return quotations;
  }

  static LanguageAssessment _language(String text) => assessLanguage(text);

  /// Évalue la langue d'un texte replié : mots d'au moins deux lettres et
  /// part de mots français fréquents.
  static LanguageAssessment assessLanguage(String foldedText) {
    final words = _word
        .allMatches(foldedText)
        .map((m) => m[0]!)
        .where((w) => w.length >= 2)
        .toList();
    return LanguageAssessment(
      wordCount: words.length,
      frenchWordCount: words.where(frenchWords.contains).length,
    );
  }
}
