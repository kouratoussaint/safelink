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
export 'src/url/brands.dart';
export 'src/url/idna.dart';
export 'src/url/ip_address.dart';
export 'src/url/parsed_url.dart';
export 'src/url/public_suffix_list.dart';
export 'src/url/punycode.dart';
export 'src/url/unicode_security.dart';
export 'src/url/url_analyzer.dart';
export 'src/url/url_masking.dart';
export 'src/url/url_parser.dart';
export 'src/url/url_rules.dart';
