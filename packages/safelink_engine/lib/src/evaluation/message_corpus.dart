import 'package:meta/meta.dart';
import 'package:safelink_engine/src/common/analysis.dart';
import 'package:safelink_engine/src/common/verdicts.dart';
import 'package:safelink_engine/src/message/message_analyzer.dart';

/// Message annoté du corpus `data/corpus/messages.tsv`.
@immutable
final class MessageCorpusEntry {
  /// Crée une entrée.
  const new({
    required this.line,
    required this.expected,
    required this.nature,
    required this.category,
    required this.text,
    required this.note,
  });

  /// Numéro de ligne dans le fichier.
  final int line;

  /// Verdict attendu.
  final MessageVerdict expected;

  /// `arnaque`, `legitime`, `piege` (légitime qui ressemble à une arnaque)
  /// ou `autre`.
  final String nature;

  /// Catégorie libre (`code`, `loterie`, `otp`…).
  final String category;

  /// Texte du message.
  final String text;

  /// Note de l'annotateur.
  final String note;

  /// Vrai pour une arnaque.
  bool get isScam => nature == 'arnaque';

  /// Vrai pour un message légitime, piège compris.
  bool get isLegitimate => nature == 'legitime' || nature == 'piege';
}

/// Lit le contenu d'un fichier de corpus. Lève une [FormatException] sur
/// une ligne mal formée.
List<MessageCorpusEntry> parseMessageCorpus(String content) {
  final entries = <MessageCorpusEntry>[];
  final lines = content.split('\n');
  for (final (index, line) in lines.indexed) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length != 5) {
      throw FormatException('Ligne ${index + 1} : ${parts.length} colonnes');
    }
    final expected = MessageVerdict.values.where((v) => v.code == parts[0]);
    if (expected.isEmpty) {
      throw FormatException('Ligne ${index + 1} : verdict ${parts[0]}');
    }
    if (!const {'arnaque', 'legitime', 'piege', 'autre'}.contains(parts[1])) {
      throw FormatException('Ligne ${index + 1} : nature ${parts[1]}');
    }
    entries.add(
      MessageCorpusEntry(
        line: index + 1,
        expected: expected.single,
        nature: parts[1],
        category: parts[2],
        text: decodeCorpusText(parts[3]),
        note: parts[4],
      ),
    );
  }
  return entries;
}

/// Texte d'une entrée : `\n` devient un retour à la ligne, `<vide>` un
/// texte vide, `<long:N>` un texte de N caractères.
String decodeCorpusText(String raw) {
  if (raw == '<vide>') return '';
  final long = RegExp(r'^<long:(\d+)>$').firstMatch(raw);
  if (long != null) {
    const sentence = 'Bonjour, voici des nouvelles de la famille. ';
    final length = int.parse(long[1]!);
    return (sentence * (length ~/ sentence.length + 1)).substring(0, length);
  }
  return raw.replaceAll(r'\n', '\n');
}

/// Résultat d'une entrée.
@immutable
final class MessageCorpusOutcome {
  /// Crée un résultat.
  const new(this.entry, this.result);

  /// Entrée évaluée.
  final MessageCorpusEntry entry;

  /// Analyse obtenue.
  final MessageAnalysisResult result;

  /// Vrai si le verdict est celui attendu.
  bool get matches => result.verdict == entry.expected;

  /// Vrai si le message est signalé (« suspect » ou « forts indices »).
  bool get flagged =>
      result.verdict == MessageVerdict.highRiskMessage ||
      result.verdict == MessageVerdict.suspiciousMessage;
}

/// Seuils bloquants de l'évaluation.
@immutable
final class MessageCorpusThresholds {
  /// Crée des seuils.
  const new({
    this.minScamRecall = 0.90,
    this.maxLegitimateHighRisk = 0,
    this.maxLegitimateFlaggedRate = 0.25,
    this.minEntries = 150,
  });

  /// Part minimale des arnaques signalées.
  final double minScamRecall;

  /// Nombre maximal de messages légitimes classés « forts indices ».
  final int maxLegitimateHighRisk;

  /// Part maximale de messages légitimes signalés comme suspects.
  final double maxLegitimateFlaggedRate;

  /// Taille minimale du corpus.
  final int minEntries;
}

/// Rapport d'évaluation du corpus.
final class MessageCorpusReport {
  /// Évalue [entries] avec [analyzer].
  factory evaluate(
    List<MessageCorpusEntry> entries,
    MessageAnalyzer analyzer, {
    AnalysisContext? context,
    MessageCorpusThresholds thresholds = const MessageCorpusThresholds(),
  }) {
    final ctx = context ?? AnalysisContext(clock: () => DateTime.utc(2026));
    return MessageCorpusReport._([
      for (final entry in entries)
        MessageCorpusOutcome(entry, analyzer.analyze(entry.text, ctx)),
    ], thresholds);
  }

  new _(this.outcomes, this.thresholds);

  /// Résultats, dans l'ordre du corpus.
  final List<MessageCorpusOutcome> outcomes;

  /// Seuils appliqués.
  final MessageCorpusThresholds thresholds;

  Iterable<MessageCorpusOutcome> get _scams =>
      outcomes.where((o) => o.entry.isScam);

  Iterable<MessageCorpusOutcome> get _legitimate =>
      outcomes.where((o) => o.entry.isLegitimate);

  /// Part des arnaques signalées (rappel).
  double get scamRecall => _ratio(_scams.where((o) => o.flagged), _scams);

  /// Part des arnaques classées « forts indices ».
  double get scamHighRiskRate => _ratio(
    _scams.where((o) => o.result.verdict == MessageVerdict.highRiskMessage),
    _scams,
  );

  /// Messages légitimes classés « forts indices ».
  List<MessageCorpusOutcome> get legitimateHighRisk => _legitimate
      .where((o) => o.result.verdict == MessageVerdict.highRiskMessage)
      .toList();

  /// Part des messages légitimes signalés.
  double get legitimateFlaggedRate =>
      _ratio(_legitimate.where((o) => o.flagged), _legitimate);

  /// Précision : part des messages signalés qui sont des arnaques.
  double get precision {
    final flagged = outcomes.where((o) => o.flagged);
    return _ratio(flagged.where((o) => o.entry.isScam), flagged);
  }

  /// Part des verdicts identiques à l'annotation.
  double get agreement => _ratio(outcomes.where((o) => o.matches), outcomes);

  /// Échecs aux seuils ; vide si tout est conforme.
  List<String> get failures {
    final failures = <String>[];
    if (outcomes.length < thresholds.minEntries) {
      failures.add(
        'Corpus trop petit : ${outcomes.length} messages (minimum '
        '${thresholds.minEntries}).',
      );
    }
    if (scamRecall < thresholds.minScamRecall) {
      failures.add(
        'Arnaques signalées : ${_percent(scamRecall)} (minimum '
        '${_percent(thresholds.minScamRecall)}).',
      );
    }
    final high = legitimateHighRisk;
    if (high.length > thresholds.maxLegitimateHighRisk) {
      final lines = high.map((o) => o.entry.line).join(', ');
      failures.add(
        '${high.length} message(s) légitime(s) classé(s) « Forts indices » : '
        'lignes $lines.',
      );
    }
    if (legitimateFlaggedRate > thresholds.maxLegitimateFlaggedRate) {
      failures.add(
        'Messages légitimes signalés : ${_percent(legitimateFlaggedRate)} '
        '(maximum ${_percent(thresholds.maxLegitimateFlaggedRate)}).',
      );
    }
    return failures;
  }

  /// Rapport lisible en Markdown.
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('## Évaluation du corpus de messages')
      ..writeln()
      ..writeln('| Mesure | Valeur | Seuil |')
      ..writeln('| --- | --- | --- |')
      ..writeln(
        '| Messages | ${outcomes.length} | ≥ ${thresholds.minEntries} |',
      )
      ..writeln(
        '| Arnaques signalées (rappel) | ${_percent(scamRecall)} | '
        '≥ ${_percent(thresholds.minScamRecall)} |',
      )
      ..writeln(
        '| Arnaques en « Forts indices » | ${_percent(scamHighRiskRate)} | — |',
      )
      ..writeln(
        '| Légitimes en « Forts indices » | ${legitimateHighRisk.length} | '
        '≤ ${thresholds.maxLegitimateHighRisk} |',
      )
      ..writeln(
        '| Légitimes signalés | ${_percent(legitimateFlaggedRate)} | '
        '≤ ${_percent(thresholds.maxLegitimateFlaggedRate)} |',
      )
      ..writeln('| Précision | ${_percent(precision)} | — |')
      ..writeln('| Accord avec l’annotation | ${_percent(agreement)} | — |')
      ..writeln()
      ..writeln('| Nature | Catégorie | Messages | Signalés | Forts indices |')
      ..writeln('| --- | --- | --- | --- | --- |');
    final groups = <(String, String), List<MessageCorpusOutcome>>{};
    for (final outcome in outcomes) {
      (groups[(outcome.entry.nature, outcome.entry.category)] ??= []).add(
        outcome,
      );
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final byNature = a.$1.compareTo(b.$1);
        return byNature != 0 ? byNature : a.$2.compareTo(b.$2);
      });
    for (final key in keys) {
      final group = groups[key]!;
      final high = group
          .where((o) => o.result.verdict == MessageVerdict.highRiskMessage)
          .length;
      buffer.writeln(
        '| ${key.$1} | ${key.$2} | ${group.length} | '
        '${group.where((o) => o.flagged).length} | $high |',
      );
    }
    final disagreements = outcomes.where((o) => !o.matches).toList();
    if (disagreements.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Écarts avec l’annotation :')
        ..writeln();
      for (final o in disagreements) {
        buffer.writeln(
          '- ligne ${o.entry.line} (${o.entry.nature}, ${o.entry.category}) : '
          'attendu ${o.entry.expected.code}, obtenu ${o.result.verdict.code}',
        );
      }
    }
    return buffer.toString();
  }

  static double _ratio(
    Iterable<MessageCorpusOutcome> part,
    Iterable<MessageCorpusOutcome> whole,
  ) => whole.isEmpty ? 1 : part.length / whole.length;

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')} %';
}
