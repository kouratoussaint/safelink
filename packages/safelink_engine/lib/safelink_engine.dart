/// Moteur de détection de SafeLink.
///
/// Dart pur : aucune dépendance à Flutter, aucun accès réseau. Les verdicts
/// sont prudents par construction et ne qualifient jamais un contenu de sûr.
library;

export 'src/common/analysis.dart';
export 'src/common/codes.dart' show stableCodePattern;
export 'src/common/content_type.dart';
export 'src/common/notes.dart';
export 'src/common/provider_result.dart';
export 'src/common/signal.dart';
export 'src/common/verdicts.dart';
