import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Composants embarqués hors packages Dart, avec le fichier de leur licence.
const embeddedLicenseAssets = [
  ('Poppins', 'assets/fonts/OFL-Poppins.txt'),
  ('Inter', 'assets/fonts/OFL-Inter.txt'),
  ('Public Suffix List', 'assets/licenses/public_suffix_list.txt'),
];

/// Ajoute les licences des polices et des données embarquées à la page
/// « Licences des composants », à côté de celles que Flutter collecte pour
/// les packages.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (component, asset) in embeddedLicenseAssets) {
      final text = await rootBundle.loadString(asset);
      yield LicenseEntryWithLineBreaks([component], text);
    }
  });
}
