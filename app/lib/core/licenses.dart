import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ajoute les licences des polices embarquées à la page « Licences des
/// composants », à côté de celles que Flutter collecte pour les packages.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, asset) in const [
      ('Poppins', 'assets/fonts/OFL-Poppins.txt'),
      ('Inter', 'assets/fonts/OFL-Inter.txt'),
    ]) {
      final text = await rootBundle.loadString(asset);
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}
