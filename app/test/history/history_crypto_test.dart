import 'package:flutter_test/flutter_test.dart';
import 'package:safelink/features/history/history_crypto.dart';

void main() {
  late MemoryHistoryKeyStore keys;
  late HistoryCipher cipher;

  setUp(() async {
    keys = MemoryHistoryKeyStore();
    cipher = await HistoryCipher.open(keys);
  });

  test('chiffre puis déchiffre', () async {
    final data = await cipher.encrypt('exemple.bf — été', 'id1', 'details');
    expect(data.first, 1);
    expect(data.length, 1 + 12 + 'exemple.bf — été'.codeUnits.length + 4 + 16);
    expect(await cipher.decrypt(data, 'id1', 'details'), 'exemple.bf — été');
  });

  test('deux chiffrements du même texte diffèrent (nonce aléatoire)', () async {
    final a = await cipher.encrypt('même texte', 'id1', 'details');
    final b = await cipher.encrypt('même texte', 'id1', 'details');
    expect(a, isNot(b));
  });

  test('la clé est créée une fois puis réutilisée', () async {
    final key = List.of(keys.key!);
    final data = await cipher.encrypt('texte', 'id1', 'details');
    final reopened = await HistoryCipher.open(keys);
    expect(keys.key, key);
    expect(await reopened.decrypt(data, 'id1', 'details'), 'texte');
  });

  test('autre vérification, autre champ ou autre clé : refus', () async {
    final data = await cipher.encrypt('texte', 'id1', 'details');
    await expectLater(
      cipher.decrypt(data, 'id2', 'details'),
      throwsA(isA<HistoryDecryptionException>()),
    );
    await expectLater(
      cipher.decrypt(data, 'id1', 'content'),
      throwsA(isA<HistoryDecryptionException>()),
    );
    final other = await HistoryCipher.open(MemoryHistoryKeyStore());
    await expectLater(
      other.decrypt(data, 'id1', 'details'),
      throwsA(isA<HistoryDecryptionException>()),
    );
  });

  test('donnée altérée, tronquée ou de version inconnue : refus', () async {
    final data = await cipher.encrypt('texte', 'id1', 'details');
    final altered = List.of(data)..[20] ^= 1;
    final unknown = List.of(data)..[0] = 2;
    for (final bad in [altered, unknown, data.sublist(0, 20), <int>[]]) {
      await expectLater(
        cipher.decrypt(bad, 'id1', 'details'),
        throwsA(isA<HistoryDecryptionException>()),
      );
    }
  });
}
