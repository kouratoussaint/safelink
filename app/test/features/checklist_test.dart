import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/checklist.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  test('chaque indice de lien appartient à une seule famille', () {
    for (final code in UrlSignalCodes.all) {
      final families = urlCheckFamilies.where((f) => f.codes.contains(code));
      expect(families, hasLength(1), reason: code);
    }
    final known = UrlSignalCodes.all.toSet();
    for (final family in urlCheckFamilies) {
      expect(known, containsAll(family.codes), reason: family.id);
    }
  });

  test('chaque catégorie de message a sa ligne', () {
    expect(
      messageCheckFamilies.keys.toSet(),
      MessageSignalCategory.values.toSet(),
    );
    final codes = {
      for (final family in messageCheckFamilies.values) ...family.codes,
    };
    expect(codes, MessageSignalCodes.all.toSet());
  });

  test('lien propre hors ligne : contrôles locaux seulement, tous verts', () {
    final outcome = DeviceAnalysisService.analyzeNow(
      AnalysisKind.link,
      'https://lefaso.net/actualites',
    );
    final items = ChecklistSection.of(outcome, l10n);
    expect(items, hasLength(7));
    expect(items.map((i) => i.worst), everyElement(isNull));
    expect(items.map((i) => i.label), contains('Connexion chiffrée (https)'));
    expect(
      items.map((i) => i.label),
      contains('Aucune imitation des 46 marques de référence'),
    );
  });

  test('lien suspect : lignes en défaut, gravité la plus forte', () {
    final outcome = DeviceAnalysisService.analyzeNow(
      AnalysisKind.link,
      'http://paypal.com.secure-login.xyz/verify',
    );
    final items = {
      for (final item in ChecklistSection.of(outcome, l10n)) item.label: item,
    };
    expect(items['Nom de marque utilisé ou imité']!.worst, Severity.high);
    expect(items['Mots d’appât dans le nom']!.worst, Severity.medium);
    expect(items['Connexion non chiffrée (http)']!.worst, Severity.info);
  });

  test('message : une ligne par catégorie', () {
    final outcome = DeviceAnalysisService.analyzeNow(
      AnalysisKind.message,
      'Envoyez le code reçu par SMS au 70 00 00 00 avant ce soir.',
    );
    final items = ChecklistSection.of(outcome, l10n);
    expect(items, hasLength(MessageSignalCategory.values.length));
    expect(
      items.map((i) => i.label),
      contains('Demande de code, de PIN ou de mot de passe'),
    );
    expect(items.map((i) => i.label), contains('Pression ou urgence'));
  });

  test('rien à lister pour un texte non analysable', () {
    expect(
      ChecklistSection.of(
        DeviceAnalysisService.analyzeNow(AnalysisKind.link, 'mailto:a@b.bf'),
        l10n,
      ),
      isEmpty,
    );
    expect(
      ChecklistSection.of(
        DeviceAnalysisService.analyzeNow(AnalysisKind.message, ''),
        l10n,
      ),
      isEmpty,
    );
  });
}
