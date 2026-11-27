import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/history/history_crypto.dart';
import 'package:safelink/features/history/history_entry.dart';
import 'package:safelink_engine/safelink_engine.dart';
import 'package:sqflite/sqflite.dart';

/// Stockage des vérifications enregistrées.
abstract interface class HistoryStore {
  /// Nombre maximal de vérifications gardées : les plus anciennes sont
  /// effacées au-delà.
  static const maxEntries = 500;

  /// Toutes les vérifications, de la plus récente à la plus ancienne.
  Future<List<HistoryEntry>> entries();

  /// Ajoute [entry].
  Future<void> add(HistoryEntry entry);

  /// Conserve ou efface ([content] nul) le contenu complet de [id].
  Future<void> setContent(String id, String? content);

  /// Supprime la vérification [id].
  Future<void> delete(String id);

  /// Supprime toutes les vérifications.
  Future<void> clear();
}

/// Identifiant aléatoire de 128 bits, en hexadécimal.
String newHistoryId([Random? random]) {
  final source = random ?? Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Ouvre l'historique.
abstract interface class HistoryBackend {
  /// Vrai si un historique existe déjà sur le téléphone.
  Future<bool> exists();

  /// Ouvre l'historique, en le créant si besoin.
  Future<HistoryStore> open();
}

/// Historique SQLite du téléphone (`sqflite`), champs sensibles chiffrés.
///
/// Rien n'est créé (ni fichier, ni clé) avant la première ouverture, qui
/// n'a lieu qu'une fois l'historique activé.
final class SqfliteHistoryBackend implements HistoryBackend {
  /// Crée l'accès ; [factory] et [path] sont remplaçables pour les tests.
  new({this.factory, this.path, this.keys = const SecureHistoryKeyStore()});

  static const fileName = 'historique.db';

  /// Fabrique de bases ; celle du téléphone par défaut.
  final DatabaseFactory? factory;

  /// Emplacement de la base ; dossier privé de l'application par défaut.
  final String? path;

  /// Clé de chiffrement.
  final HistoryKeyStore keys;
  Future<HistoryStore>? _store;

  DatabaseFactory get _databases => factory ?? databaseFactory;

  Future<String> _location() async =>
      path ?? p.join(await _databases.getDatabasesPath(), fileName);

  @override
  Future<bool> exists() async =>
      _store != null || await _databases.databaseExists(await _location());

  @override
  Future<HistoryStore> open() async {
    final pending = _store ??= _open();
    try {
      return await pending;
    } on Object {
      // Une nouvelle tentative rouvrira la base.
      _store = null;
      rethrow;
    }
  }

  Future<HistoryStore> _open() async {
    final cipher = await HistoryCipher.open(keys);
    final database = await _databases.openDatabase(
      await _location(),
      options: OpenDatabaseOptions(
        // Version du schéma : toute évolution passera par onUpgrade.
        version: 1,
        onConfigure: (db) async {
          // Les lignes effacées sont écrasées sur le disque.
          await db.execute('PRAGMA secure_delete = ON');
        },
        onCreate: (db, version) => db.execute('''
          CREATE TABLE entries (
            id TEXT PRIMARY KEY,
            content_type TEXT NOT NULL,
            level TEXT NOT NULL,
            verdict TEXT NOT NULL,
            analyzed_at INTEGER NOT NULL,
            rules_version TEXT NOT NULL,
            signal_codes TEXT NOT NULL,
            details BLOB NOT NULL,
            content BLOB
          )'''),
      ),
    );
    return SqfliteHistoryStore(database, cipher);
  }
}

/// Historique dans une base SQLite.
final class SqfliteHistoryStore implements HistoryStore {
  /// Crée le stockage.
  new(this._db, this._cipher);

  final Database _db;
  final HistoryCipher _cipher;

  static const _details = 'details';
  static const _content = 'content';

  @override
  Future<List<HistoryEntry>> entries() async {
    final rows = await _db.query('entries', orderBy: 'analyzed_at DESC');
    return [for (final row in rows) await _entry(row)];
  }

  Future<HistoryEntry> _entry(Map<String, Object?> row) async {
    final id = row['id']! as String;
    HistoryDetails? details;
    String? content;
    try {
      details = HistoryDetails.decode(
        await _cipher.decrypt(row[_details]! as Uint8List, id, _details),
      );
      final encrypted = row[_content] as Uint8List?;
      if (encrypted != null) {
        content = await _cipher.decrypt(encrypted, id, _content);
      }
    } on HistoryDecryptionException {
      details = null;
      content = null;
    }
    final codes = row['signal_codes']! as String;
    return HistoryEntry(
      id: id,
      kind: AnalysisKind.values.byName(row['content_type']! as String),
      level: RiskLevel.values.byName(row['level']! as String),
      verdictCode: row['verdict']! as String,
      analyzedAt: DateTime.fromMillisecondsSinceEpoch(
        row['analyzed_at']! as int,
        isUtc: true,
      ),
      rulesVersion: row['rules_version']! as String,
      signalCodes: codes.isEmpty ? const [] : codes.split(','),
      details: details,
      content: content,
    );
  }

  @override
  Future<void> add(HistoryEntry entry) async {
    final details = entry.details;
    if (details == null) {
      throw ArgumentError('Une vérification à enregistrer a son détail.');
    }
    final content = entry.content;
    final row = {
      'id': entry.id,
      'content_type': entry.kind.name,
      'level': entry.level.name,
      'verdict': entry.verdictCode,
      'analyzed_at': entry.analyzedAt.toUtc().millisecondsSinceEpoch,
      'rules_version': entry.rulesVersion,
      'signal_codes': entry.signalCodes.join(','),
      _details: await _cipher.encrypt(details.encode(), entry.id, _details),
      _content: content == null
          ? null
          : await _cipher.encrypt(content, entry.id, _content),
    };
    await _db.transaction((txn) async {
      await txn.insert('entries', row);
      // Au-delà du plafond, les plus anciennes sont effacées.
      await txn.rawDelete(
        'DELETE FROM entries WHERE id NOT IN '
        '(SELECT id FROM entries ORDER BY analyzed_at DESC LIMIT ?)',
        [HistoryStore.maxEntries],
      );
    });
  }

  @override
  Future<void> setContent(String id, String? content) async {
    await _db.update(
      'entries',
      {
        _content: content == null
            ? null
            : await _cipher.encrypt(content, id, _content),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) =>
      _db.delete('entries', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> clear() async {
    await _db.delete('entries');
    // Rend au système les pages libérées.
    await _db.execute('VACUUM');
  }
}

/// Historique en mémoire, pour les tests.
final class MemoryHistoryBackend implements HistoryBackend, HistoryStore {
  final _entries = <String, HistoryEntry>{};
  bool _opened = false;

  /// Nombre d'ouvertures (une seule attendue).
  int openings = 0;

  @override
  Future<bool> exists() async => _opened;

  @override
  Future<HistoryStore> open() async {
    if (!_opened) openings++;
    _opened = true;
    return this;
  }

  @override
  Future<List<HistoryEntry>> entries() async =>
      _entries.values.toList()
        ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));

  @override
  Future<void> add(HistoryEntry entry) async {
    _entries[entry.id] = entry;
    final sorted = await entries();
    for (final old in sorted.skip(HistoryStore.maxEntries)) {
      _entries.remove(old.id);
    }
  }

  @override
  Future<void> setContent(String id, String? content) async {
    final entry = _entries[id];
    if (entry != null) _entries[id] = entry.withContent(content);
  }

  @override
  Future<void> delete(String id) async => _entries.remove(id);

  @override
  Future<void> clear() async => _entries.clear();
}
