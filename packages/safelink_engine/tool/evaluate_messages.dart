// Évalue le corpus de messages et échoue si un seuil n'est pas atteint.
//
// Usage, depuis packages/safelink_engine :
//   dart run tool/evaluate_messages.dart [--corpus <fichier>] [--report <fichier>]
import 'dart:io';

import 'package:safelink_engine/safelink_engine.dart';
import 'package:safelink_engine/src/evaluation/message_corpus.dart';

void main(List<String> args) {
  var corpus = '../../data/corpus/messages.tsv';
  String? reportPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--corpus' && i + 1 < args.length) corpus = args[++i];
    if (args[i] == '--report' && i + 1 < args.length) reportPath = args[++i];
  }
  final entries = parseMessageCorpus(File(corpus).readAsStringSync());
  final report = MessageCorpusReport.evaluate(entries, MessageAnalyzer());
  final markdown = report.toMarkdown();
  stdout.writeln(markdown);
  if (reportPath != null) {
    File(reportPath).writeAsStringSync(markdown, mode: FileMode.append);
  }
  final failures = report.failures;
  if (failures.isNotEmpty) {
    stderr.writeln('Seuils non atteints :');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
  }
}
