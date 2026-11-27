import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les licences des composants embarqués sont enregistrées', () async {
    registerAssetLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((entry) => entry.packages).toSet();
    for (final (component, _) in embeddedLicenseAssets) {
      expect(packages, contains(component));
    }

    final psl = entries.firstWhere(
      (entry) => entry.packages.contains('Public Suffix List'),
    );
    final text = psl.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Mozilla Public License Version 2.0'));
    expect(text, contains('psl_data.g.dart'));
  });
}
