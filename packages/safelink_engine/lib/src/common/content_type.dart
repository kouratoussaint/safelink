/// Type de contenu soumis à l'analyse.
///
/// Le MVP ne traite que les liens et les messages textuels. Les images,
/// documents et vidéos sont prévus pour des versions ultérieures et
/// s'ajouteront ici sans modifier les types existants.
enum ContentType {
  /// Adresse web (`http` ou `https`), saisie, collée, partagée ou issue
  /// d'un QR code.
  url('url'),

  /// Message textuel collé, saisi ou partagé volontairement.
  message('message');

  new(this.code);

  /// Code stable utilisé dans l'historique et les exports.
  final String code;
}
