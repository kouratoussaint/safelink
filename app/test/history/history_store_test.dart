import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_crypto.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink/features/history/history_store.dart';
import 'package:safelink_engine/safelink_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const secretUrl =
    'https://paypal.com.secure-login.xyz/verify?token=abcdefghijklmnopqrstuvwxyz123456';
const secretMessage =
    'Bonjour Awa, ton colis est bloqué. Paie 2 000 F de frais sur '
    'https://colis-bf.example/pay et envoie le code reçu par SMS.';

HistoryEntry entryOf(
  AnalysisKind kind,
  String text, {
  DateTime? at,
  String? id,
}) {
  final base = HistoryEntry.fromOutcome(
    id ?? newHistoryId(),
    LocalAnalysisService.analyzeNow(kind, text),
  );
  return HistoryEntry(
    id: base.id,
    kind: base.kind,
    level: base.level,
    verdictCode: base.verdictCode,
    analyzedAt: (at ?? base.analyzedAt).toUtc(),
    rulesVersion: base.rulesVersion,
    signalCodes: base.signalCodes,
    details: base.details,
  );
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late String path;
  late MemoryHistoryKeyStore keys;

  SqfliteHistoryBackend backend({HistoryKeyStore? keyStore}) =>
      SqfliteHistoryBackend(
        factory: databaseFactoryFfi,
        path: path,
        keys: keyStore ?? keys,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safelink_history');
    path = '${dir.path}/historique.db';
    keys = MemoryHistoryKeyStore();
  });

  tearDown(() async {
    await databaseFactoryFfi.deleteDatabase(path);
    await dir.delete(recursive: true);
  });

  test('rien n’est créé avant la première ouverture', () async {
    final history = backend();
    expect(await history.exists(), isFalse);
    expect(File(path).existsSync(), isFalse);
    expect(keys.key, isNull);

    await history.open();
    expect(await history.exists(), isTrue);
    expect(keys.key, hasLength(32));
  });

  test('enregistre et relit, de la plus récente à la plus ancienne', () async {
    final store = await backend().open();
    final older = entryOf(
      AnalysisKind.link,
      secretUrl,
      at: DateTime.utc(2026, 11, 20),
    );
    final newer = entryOf(
      AnalysisKind.message,
      secretMessage,
      at: DateTime.utc(2026, 11, 27),
    );
    await store.add(older);
    await store.add(newer);

    final entries = await store.entries();
    expect(entries, [newer, older]);
    expect(entries.last.details!.domain, 'secure-login.xyz');
    expect(entries.last.content, isNull);
    expect(entries.first.details!.links.single.domain, 'colis-bf.example');
    expect(entries.first.details!.signals, isNotEmpty);
  });

  test(
    'le fichier ne contient ni domaine, ni lien, ni message en clair',
    () async {
      final store = await backend().open();
      final link = entryOf(AnalysisKind.link, secretUrl);
      final message = entryOf(AnalysisKind.message, secretMessage);
      await store.add(link);
      await store.add(message);
      await store.setContent(link.id, secretUrl);
      await store.setContent(message.id, secretMessage);

      final database = await databaseFactoryFfi.openDatabase(path);
      await database.close();
      final bytes = latin1.decode(File(path).readAsBytesSync());
      for (final secret in [
        'secure-login',
        'colis-bf',
        'abcdefghijklmnop',
        'Awa',
        'frais',
        'PayPal',
      ]) {
        expect(bytes, isNot(contains(secret)), reason: secret);
        expect(
          bytes,
          isNot(contains(latin1.decode(utf8.encode(secret)))),
          reason: secret,
        );
      }
      // Les champs non sensibles restent lisibles pour les filtres.
      expect(bytes, contains('SUSPICIOUS'));
    },
  );

  test('contenu complet conservé puis effacé sur demande', () async {
    final store = await backend().open();
    final entry = entryOf(AnalysisKind.message, secretMessage);
    await store.add(entry);

    await store.setContent(entry.id, secretMessage);
    expect((await store.entries()).single.content, secretMessage);

    await store.setContent(entry.id, null);
    expect((await store.entries()).single.content, isNull);
  });

  test('suppression unitaire et totale', () async {
    final store = await backend().open();
    final first = entryOf(AnalysisKind.link, 'https://example.com');
    final second = entryOf(AnalysisKind.link, 'https://exemple.bf');
    await store.add(first);
    await store.add(second);

    await store.delete(first.id);
    expect((await store.entries()).map((e) => e.id), [second.id]);

    await store.clear();
    expect(await store.entries(), isEmpty);
  });

  test(
    'au-delà de 500 vérifications, les plus anciennes sont effacées',
    () async {
      final store = await backend().open();
      final start = DateTime.utc(2026);
      final template = entryOf(AnalysisKind.link, 'https://example.com');
      for (var i = 0; i < HistoryStore.maxEntries + 5; i++) {
        await store.add(
          HistoryEntry(
            id: 'id-$i',
            kind: template.kind,
            level: template.level,
            verdictCode: template.verdictCode,
            analyzedAt: start.add(Duration(minutes: i)),
            rulesVersion: template.rulesVersion,
            signalCodes: template.signalCodes,
            details: template.details,
          ),
        );
      }
      final entries = await store.entries();
      expect(entries, hasLength(HistoryStore.maxEntries));
      expect(entries.last.id, 'id-5');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('clé perdue : vérifications illisibles mais supprimables', () async {
    final store = await backend().open();
    final entry = entryOf(AnalysisKind.link, secretUrl);
    await store.add(entry);
    await store.setContent(entry.id, secretUrl);

    final other = await backend(keyStore: MemoryHistoryKeyStore()).open();
    final unreadable = (await other.entries()).single;
    expect(unreadable.isUnreadable, isTrue);
    expect(unreadable.content, isNull);
    expect(unreadable.verdictCode, entry.verdictCode);
    expect(unreadable.level, entry.level);

    await other.delete(entry.id);
    expect(await other.entries(), isEmpty);
  });

  test('un champ chiffré recopié dans une autre ligne est refusé', () async {
    final store = await backend().open();
    final first = entryOf(AnalysisKind.link, 'https://example.com');
    final second = entryOf(AnalysisKind.link, secretUrl);
    await store.add(first);
    await store.add(second);

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final rows = await database.query(
      'entries',
      columns: ['details'],
      where: 'id = ?',
      whereArgs: [second.id],
    );
    await database.update(
      'entries',
      {'details': rows.single['details']},
      where: 'id = ?',
      whereArgs: [first.id],
    );
    await database.close();

    final entries = await store.entries();
    expect(entries.firstWhere((e) => e.id == first.id).isUnreadable, isTrue);
    expect(entries.firstWhere((e) => e.id == second.id).isUnreadable, isFalse);
  });

  test('identifiants aléatoires de 128 bits', () {
    final ids = {for (var i = 0; i < 100; i++) newHistoryId()};
    expect(ids, hasLength(100));
    expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('le détail ne garde jamais les extraits', () {
    final entry = entryOf(AnalysisKind.message, secretMessage);
    final encoded = entry.details!.encode();
    expect(encoded, isNot(contains('Awa')));
    expect(encoded, isNot(contains('envoie le code')));
    expect(HistoryDetails.decode(encoded), entry.details);
    expect(entry.level, RiskLevel.danger);
    expect(entry.toString(), isNot(contains('colis')));
  });
}
