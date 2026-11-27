/// Niveau de synthèse affiché dans le bandeau d'un résultat.
///
/// Il sert à combiner l'analyse d'un message et celle des liens qu'il
/// contient : le niveau le plus sévère l'emporte toujours, si bien qu'un
/// message au ton rassurant ne peut pas masquer un lien dangereux.
enum RiskLevel {
  /// Entrée non analysable (vide, trop longue, protocole non pris en
  /// charge).
  notAnalyzable(0),

  /// Aucun indice relevé par les vérifications réellement effectuées.
  nothingObvious(1),

  /// Analyse insuffisante : une vérification pertinente n'a pas pu être
  /// menée ou n'a rien permis de conclure.
  uncertain(2),

  /// Indices de tromperie explicables, sans certitude de fraude.
  attention(3),

  /// Menace connue ou forts indices d'arnaque.
  danger(4);

  new(this.rank);

  /// Rang de sévérité : plus il est élevé, plus le niveau est grave.
  final int rank;

  /// Renvoie le niveau le plus sévère parmi [levels].
  ///
  /// Lève une [ArgumentError] si [levels] est vide : l'absence de
  /// résultat ne doit jamais être traduite en niveau rassurant.
  static RiskLevel mostSevere(Iterable<RiskLevel> levels) {
    final iterator = levels.iterator;
    if (!iterator.moveNext()) {
      throw ArgumentError.value(
        levels,
        'levels',
        'Au moins un niveau est requis.',
      );
    }
    var result = iterator.current;
    while (iterator.moveNext()) {
      if (iterator.current.rank > result.rank) {
        result = iterator.current;
      }
    }
    return result;
  }
}

/// Verdict d'une analyse de lien (cahier des charges, F06).
enum UrlVerdict {
  /// « Menace connue détectée » : correspondance valide et récente avec une
  /// source de menaces fiable. Jamais produit par les seules heuristiques.
  knownThreat('KNOWN_THREAT', RiskLevel.danger),

  /// « Lien suspect » : indices explicables, sans certitude de fraude.
  suspicious('SUSPICIOUS', RiskLevel.attention),

  /// « Aucun danger connu détecté » : uniquement si une source de
  /// réputation à jour a été consultée. Ne garantit pas que le lien est sûr.
  noKnownThreat('NO_KNOWN_THREAT', RiskLevel.nothingObvious),

  /// « Analyse insuffisante » : source indisponible, périmée ou non
  /// concluante.
  inconclusive('INCONCLUSIVE', RiskLevel.uncertain),

  /// « Adresse non analysable » : saisie invalide ou protocole non pris en
  /// charge.
  invalid('INVALID', RiskLevel.notAnalyzable);

  new(this.code, this.level);

  /// Code normatif du cahier des charges.
  final String code;

  /// Niveau de synthèse correspondant.
  final RiskLevel level;
}

/// Verdict d'une analyse de message (cahier des charges, F03bis).
///
/// Aucun verdict n'affirme qu'un message est authentique ou véridique.
enum MessageVerdict {
  /// « Forts indices d'arnaque ».
  highRiskMessage('HIGH_RISK_MESSAGE', RiskLevel.danger),

  /// « Message suspect ».
  suspiciousMessage('SUSPICIOUS_MESSAGE', RiskLevel.attention),

  /// « Aucun indice évident relevé ».
  noObviousSignals('NO_OBVIOUS_SIGNALS', RiskLevel.nothingObvious),

  /// « Analyse insuffisante ».
  inconclusiveMessage('INCONCLUSIVE_MESSAGE', RiskLevel.uncertain),

  /// « Message non analysable ».
  invalidMessage('INVALID_MESSAGE', RiskLevel.notAnalyzable);

  new(this.code, this.level);

  /// Code normatif du cahier des charges.
  final String code;

  /// Niveau de synthèse correspondant.
  final RiskLevel level;
}
