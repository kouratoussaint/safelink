/// Format commun des codes stables (signaux, limites, actions, erreurs) :
/// majuscules, chiffres et tirets bas, de 3 à 64 caractères, commençant par
/// une lettre. Exemple : `USERINFO_PRESENT`.
final RegExp stableCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{2,63}$');

/// Vérifie qu'un code respecte [stableCodePattern].
///
/// Lève une [ArgumentError] nommée d'après [name] dans le cas contraire.
String checkStableCode(String code, String name) {
  if (!stableCodePattern.hasMatch(code)) {
    throw ArgumentError.value(
      code,
      name,
      'Code attendu en MAJUSCULES_AVEC_TIRETS_BAS (3 à 64 caractères).',
    );
  }
  return code;
}

/// Vérifie qu'un texte destiné à l'utilisateur n'est pas vide.
String checkNotBlank(String text, String name) {
  if (text.trim().isEmpty) {
    throw ArgumentError.value(text, name, 'Le texte ne peut pas être vide.');
  }
  return text;
}

/// Vérifie qu'une date est exprimée en UTC, pour des horodatages
/// comparables quel que soit le fuseau du téléphone.
DateTime checkUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'La date doit être en UTC.');
  }
  return value;
}
