import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Révision Git injectée à la compilation par la CI
/// (`--dart-define=SAFELINK_GIT_SHA=<sha>`) ; vide pour un build local.
const gitRevision = String.fromEnvironment('SAFELINK_GIT_SHA');

/// Adresse publique du dépôt.
const sourceRepositoryUrl = 'https://github.com/kouratoussaint/safelink';

/// Informations de version de l'application installée.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);
