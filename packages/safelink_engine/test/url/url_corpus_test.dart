import 'dart:io';
import 'dart:math';

import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

/// Entrée du corpus annoté `test/data/url_corpus.tsv`.
final class CorpusEntry {
  new(this.line, this.verdict, this.url, this.codes, this.note);

  final int line;
  final String verdict;
  final String url;
  final List<String> codes;
  final String note;
}

String decodeCorpusUrl(String raw) {
  if (raw == '<vide>') return '';
  final long = RegExp(r'^<long:(\d+)>$').firstMatch(raw);
  if (long != null) {
    final length = int.parse(long[1]!);
    const prefix = 'https://example.com/';
    return prefix + 'a' * (length - prefix.length);
  }
  return raw.replaceAllMapped(
    RegExp(r'\\u([0-9A-Fa-f]{4})'),
    (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
  );
}

List<CorpusEntry> loadCorpus() {
  final entries = <CorpusEntry>[];
  final lines = File('test/data/url_corpus.tsv').readAsLinesSync();
  for (final (index, line) in lines.indexed) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length != 4) {
      throw FormatException(
        'Ligne ${index + 1} : ${parts.length} colonnes',
        line,
      );
    }
    entries.add(
      CorpusEntry(
        index + 1,
        parts[0],
        decodeCorpusUrl(parts[1]),
        parts[2] == '-' ? const [] : parts[2].split(','),
        parts[3],
      ),
    );
  }
  return entries;
}

void main() {
  final analyzer = UrlAnalyzer();
  final context = AnalysisContext(clock: () => DateTime.utc(2026, 11, 27));
  final corpus = loadCorpus();

  group('corpus annoté', () {
    test('au moins 150 liens, toutes les catégories représentées', () {
      expect(corpus.length, greaterThanOrEqualTo(150));
      final verdicts = corpus.map((e) => e.verdict).toSet();
      expect(verdicts, containsAll(['SUSPICIOUS', 'INCONCLUSIVE', 'INVALID']));
      final urls = corpus.map((e) => e.url).toList();
      expect(urls.toSet(), hasLength(urls.length), reason: 'doublons');
    });

    for (final entry in corpus) {
      test('ligne ${entry.line} : ${entry.note}', () {
        final result = analyzer.analyze(entry.url, context);
        final codes = result.signals.map((s) => s.code).toSet();
        final where =
            '${entry.url.length > 80 ? entry.url.substring(0, 80) : entry.url}'
            ' → ${result.verdict.code} $codes';
        expect(result.verdict.code, entry.verdict, reason: where);
        for (final expected in entry.codes) {
          if (expected == 'quiet') {
            expect(
              result.signals.where((s) => s.severity.rank >= 2),
              isEmpty,
              reason: where,
            );
          } else if (expected.startsWith('!')) {
            expect(
              codes,
              isNot(contains(expected.substring(1))),
              reason: where,
            );
          } else {
            expect(codes, contains(expected), reason: where);
          }
        }
      });
    }

    test('évaluation : taux de détection et fausses alertes', () {
      var suspiciousExpected = 0;
      var suspiciousFound = 0;
      var falseAlarms = 0;
      for (final entry in corpus) {
        final verdict = analyzer.analyze(entry.url, context).verdict.code;
        if (entry.verdict == 'SUSPICIOUS') {
          suspiciousExpected++;
          if (verdict == 'SUSPICIOUS') suspiciousFound++;
        } else if (verdict == 'SUSPICIOUS') {
          falseAlarms++;
        }
      }
      // Seuils bloquants : toutes les imitations annotées sont détectées,
      // aucun lien prudent n'est déclaré suspect.
      expect(suspiciousFound, suspiciousExpected);
      expect(falseAlarms, 0);
    });
  });

  group('garanties', () {
    test('aucune règle locale ne produit KNOWN_THREAT ni NO_KNOWN_THREAT', () {
      for (final entry in corpus) {
        final verdict = analyzer.analyze(entry.url, context).verdict;
        expect(verdict, isNot(UrlVerdict.knownThreat), reason: entry.url);
        expect(verdict, isNot(UrlVerdict.noKnownThreat), reason: entry.url);
      }
      // Tous les indices possibles à la fois, sans source de réputation.
      final allSignals = [
        for (final severity in Severity.values)
          for (var i = 0; i < 5; i++)
            RiskSignal(
              code: 'TEST_${severity.name.toUpperCase()}_$i',
              severity: severity,
              confidence: Confidence.high,
              reason: 'test',
              source: SignalSource.urlHeuristic,
              detectedAt: DateTime.utc(2026),
            ),
      ];
      final (verdict, _) = const UrlVerdictPolicy().decide(allSignals, []);
      expect(verdict, UrlVerdict.suspicious);
    });

    test('entrées aléatoires : jamais d’exception', () {
      final random = Random(20261127);
      final alphabet = [
        r"abcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=% ",
        '\t\n',
        r'\^|<>{}"`',
        '\u0430\u0435\u043E\u00AD\u200B\u202E\uFF0E\u3002',
        'éàüß中文😀\u0000\u007F',
      ].join();
      final runes = alphabet.runes.toList();
      final prefixes = ['', 'http://', 'https://', 'HTTPS://', '//', 'www.'];
      for (var i = 0; i < 3000; i++) {
        final length = random.nextInt(60);
        final body = String.fromCharCodes([
          for (var j = 0; j < length; j++) runes[random.nextInt(runes.length)],
        ]);
        final input = prefixes[random.nextInt(prefixes.length)] + body;
        final result = analyzer.analyze(input, context);
        expect(result.limitations, isNotEmpty);
        expect(result.verdict, isNot(UrlVerdict.knownThreat));
        for (final signal in result.signals) {
          expect(
            signal.evidence?.length ?? 0,
            lessThanOrEqualTo(RiskSignal.maxEvidenceLength),
          );
        }
      }
    });

    test('budget de temps par lien', () {
      // Préchauffage : chargement des tables embarquées.
      analyzer.analyze('https://example.com', context);
      final stopwatch = Stopwatch()..start();
      var slowest = Duration.zero;
      for (final entry in corpus) {
        final start = stopwatch.elapsed;
        analyzer.analyze(entry.url, context);
        final elapsed = stopwatch.elapsed - start;
        if (elapsed > slowest) slowest = elapsed;
      }
      final average = stopwatch.elapsed ~/ corpus.length;
      // Marges larges pour les machines d'intégration continue.
      expect(average, lessThan(const Duration(milliseconds: 20)));
      expect(slowest, lessThan(const Duration(milliseconds: 200)));
    });

    test('chaque indice est documenté et couvert par le corpus', () {
      final doc = File('../../docs/URL_RULES.md').readAsStringSync();
      final documented = RegExp(
        r'^\| `(URL_[A-Z0-9_]+)`',
        multiLine: true,
      ).allMatches(doc).map((m) => m[1]).toList();
      expect(documented, UrlSignalCodes.all);
      expect(UrlSignalCodes.all.toSet(), hasLength(UrlSignalCodes.all.length));
      final produced = {
        for (final entry in corpus)
          ...analyzer.analyze(entry.url, context).signals.map((s) => s.code),
      };
      expect(produced, containsAll(UrlSignalCodes.all));
      expect(UrlSignalCodes.all, containsAll(produced));
    });

    test('le moteur n’effectue aucune entrée-sortie', () {
      final forbidden = RegExp(
        r'''import\s+['"](dart:(io|ffi|html|isolate|js_interop)|package:http|package:flutter)''',
      );
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          forbidden.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });
  });
}
