import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/history/history_presentation.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

import 'history_store_test.dart' show entryOf, secretMessage, secretUrl;

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));
  final now = DateTime(2026, 11, 27, 15);

  setUpAll(() => initializeDateFormatting('fr'));

  late List<HistoryEntry> entries;

  setUp(() {
    entries = [
      entryOf(AnalysisKind.link, secretUrl, at: DateTime(2026, 11, 27, 10)),
      entryOf(
        AnalysisKind.message,
        secretMessage,
        at: DateTime(2026, 11, 25, 9),
      ),
      entryOf(
        AnalysisKind.link,
        'https://example.com',
        at: DateTime(2026, 10, 1, 9),
      ),
    ];
  });

  List<int> indexesOf(HistoryFilter filter) => [
    for (final entry in filter.apply(entries, now)) entries.indexOf(entry),
  ];

  test('sans filtre, tout est gardé', () {
    expect(const HistoryFilter().isEmpty, isTrue);
    expect(indexesOf(const HistoryFilter()), [0, 1, 2]);
  });

  test('par nature', () {
    expect(indexesOf(const HistoryFilter(kind: AnalysisKind.link)), [0, 2]);
    expect(indexesOf(const HistoryFilter(kind: AnalysisKind.message)), [1]);
  });

  test('par niveau', () {
    expect(indexesOf(const HistoryFilter(levels: {RiskLevel.danger})), [1]);
    expect(
      indexesOf(
        const HistoryFilter(levels: {RiskLevel.attention, RiskLevel.uncertain}),
      ),
      [0, 2],
    );
  });

  test('par période', () {
    expect(indexesOf(const HistoryFilter(period: HistoryPeriod.today)), [0]);
    expect(indexesOf(const HistoryFilter(period: HistoryPeriod.week)), [0, 1]);
    expect(indexesOf(const HistoryFilter(period: HistoryPeriod.month)), [0, 1]);
  });

  test('par domaine, y compris les liens d’un message', () {
    expect(indexesOf(const HistoryFilter(query: 'SECURE')), [0]);
    expect(indexesOf(const HistoryFilter(query: 'colis')), [1]);
    expect(indexesOf(const HistoryFilter(query: ' example.com ')), [2]);
    expect(indexesOf(const HistoryFilter(query: 'introuvable')), isEmpty);
  });

  test('filtres combinés', () {
    final filter = const HistoryFilter().copyWith(
      kind: () => AnalysisKind.link,
      period: HistoryPeriod.week,
    );
    expect(filter.isEmpty, isFalse);
    expect(indexesOf(filter), [0]);
    expect(indexesOf(filter.copyWith(kind: () => null)), [0, 1]);
  });

  test('jours : aujourd’hui, hier, puis la date', () {
    expect(
      historyDay(DateTime(2026, 11, 27, 1).toUtc(), now, l10n),
      'Aujourd’hui',
    );
    expect(historyDay(DateTime(2026, 11, 26, 23).toUtc(), now, l10n), 'Hier');
    expect(
      historyDay(DateTime(2026, 11, 24, 12).toUtc(), now, l10n),
      'Mardi 24 novembre',
    );
    expect(
      historyDay(DateTime(2025, 11, 24, 12).toUtc(), now, l10n),
      'Lundi 24 novembre 2025',
    );
  });

  test('titres et verdicts', () {
    expect(historyTitle(entries[0], l10n), 'secure-login.xyz');
    expect(historyTitle(entries[1], l10n), 'Message · 1 lien');
    expect(historyVerdict(entries[0], l10n).label, 'Lien suspect');
    expect(historyVerdict(entries[1], l10n).label, 'Forts indices d’arnaque');
    final unreadable = HistoryEntry(
      id: 'x',
      kind: AnalysisKind.link,
      level: RiskLevel.attention,
      verdictCode: 'SUSPICIOUS',
      analyzedAt: DateTime.utc(2026),
      rulesVersion: 'url-1.0.0',
      signalCodes: const [],
      details: null,
    );
    expect(historyTitle(unreadable, l10n), 'Vérification illisible');
    expect(historyVerdict(unreadable, l10n).label, 'Lien suspect');
  });
}
