import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/results/result_summary.dart';
import 'package:safelink/features/results/verdict_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));
  String date(DateTime _) => '1 janvier 2026 à 10:00';

  group('résumé copié', () {
    test('lien : verdict, raisons, lien masqué, limites', () {
      final outcome = LocalAnalysisService.analyzeNow(
        AnalysisKind.link,
        'http://orange-money-bf.secure-login.xyz/verify'
        '?token=abcdefghijklmnopqrstuvwxyz123456',
      );
      final summary = ResultSummary.of(outcome, l10n, date);
      expect(summary, startsWith('SafeLink — résultat d’analyse'));
      expect(summary, contains('Analysé le 1 janvier 2026 à 10:00'));
      expect(summary, contains('Verdict : Lien suspect'));
      expect(
        summary,
        contains(
          'Lien : http://orange-money-bf.secure-login.xyz/verify?token=•••',
        ),
      );
      expect(summary, isNot(contains('abcdefghijklmnop')));
      expect(summary, contains('Pourquoi ce résultat ? :'));
      expect(summary, contains('Ce qui n’a pas été vérifié :'));
      expect(summary, endsWith(l10n.summaryFooter));
    });

    test('adresse non analysable : aucun lien recopié', () {
      final outcome = LocalAnalysisService.analyzeNow(
        AnalysisKind.link,
        'mailto:contact@exemple.bf',
      );
      final summary = ResultSummary.of(outcome, l10n, date);
      expect(summary, contains('Verdict : Adresse non analysable'));
      expect(summary, isNot(contains('contact@exemple.bf')));
    });

    test('message : ni texte ni extraits, liens masqués', () {
      const text =
          'Bonjour Awa, ton colis est bloqué. Paie 2 000 F de frais de '
          'livraison sur https://colis-bf.example/pay?phone=70123456 '
          'et envoie le code reçu par SMS.';
      final outcome = LocalAnalysisService.analyzeNow(
        AnalysisKind.message,
        text,
      );
      final summary = ResultSummary.of(outcome, l10n, date);
      expect(summary, contains('Message analysé (texte non reproduit)'));
      expect(summary, isNot(contains('Awa')));
      expect(summary, isNot(contains('70123456')));
      expect(summary, isNot(contains('Extrait')));
      expect(
        summary,
        contains('Lien : https://colis-bf.example/pay?phone=•••'),
      );
      final message = (outcome as MessageOutcome).result.message;
      for (final signal in message.signals) {
        expect(summary, contains(signal.reason));
        if (signal.evidence != null) {
          expect(summary, isNot(contains(signal.evidence)));
        }
      }
    });
  });

  group('présentation des verdicts', () {
    test('chaque verdict de lien a un libellé et une icône', () {
      final labels = {
        for (final input in [
          'https://example.com',
          'xn--pypal-4ve.com',
          'mailto:a@b.bf',
        ])
          VerdictPresentation.forUrl(
            UrlAnalyzer().analyze(input, const AnalysisContext()),
            l10n,
          ).label,
      };
      expect(labels, {
        'Analyse insuffisante',
        'Lien suspect',
        'Adresse non analysable',
      });
    });

    test('aucun libellé ne promet la sécurité', () {
      final all = [
        l10n.verdictKnownThreat,
        l10n.verdictSuspicious,
        l10n.verdictNoKnownThreat,
        l10n.verdictInconclusive,
        l10n.verdictInvalid,
        l10n.verdictHighRisk,
        l10n.verdictSuspiciousMessage,
        l10n.verdictNoObviousSignals,
        l10n.verdictInconclusiveMessage,
        l10n.verdictInvalidMessage,
        l10n.subtitleNoKnownThreat,
        l10n.subtitleNoObviousSignals,
      ].join(' ').toLowerCase();
      for (final forbidden in ['100 %', 'sans danger', 'fiable', 'sécurisé']) {
        expect(all, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(l10n.subtitleNoKnownThreat, contains('ne garantit pas'));
    });

    test('chaque niveau a une icône et un libellé distincts', () {
      final icons = RiskLevel.values.map(VerdictPresentation.iconOf).toSet();
      final labels = RiskLevel.values
          .map((level) => VerdictPresentation.levelLabel(l10n, level))
          .toSet();
      expect(icons, hasLength(RiskLevel.values.length));
      expect(labels, hasLength(RiskLevel.values.length));
    });
  });
}
