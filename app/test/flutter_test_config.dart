import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuration commune à tous les tests de l'application.
///
/// Charge les vraies polices déclarées (Poppins, Inter, icônes Material) au
/// lieu de la police de test par défaut, qui dessine chaque caractère comme
/// un carré plein. Les mesures de contraste et de débordement portent ainsi
/// sur un rendu proche de celui du téléphone.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadDeclaredFonts();
  await testMain();
}

Future<void> _loadDeclaredFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(manifest) as List<Object?>)
      .cast<Map<String, Object?>>();
  for (final family in families) {
    final loader = FontLoader(family['family']! as String);
    for (final font
        in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}
