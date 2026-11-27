import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Conserve la clé de chiffrement de l'historique.
abstract interface class HistoryKeyStore {
  /// Clé enregistrée, ou `null` s'il n'y en a pas encore.
  Future<List<int>?> read();

  /// Enregistre [key].
  Future<void> write(List<int> key);

  /// Supprime la clé.
  Future<void> delete();
}

/// Clé protégée par le Keystore d'Android (`flutter_secure_storage`).
///
/// La clé de l'historique est aléatoire ; elle est elle-même chiffrée par
/// une clé du Keystore, qui ne quitte jamais le téléphone. Les sauvegardes
/// d'Android sont désactivées : la clé n'est jamais copiée ailleurs.
final class SecureHistoryKeyStore implements HistoryKeyStore {
  /// Crée l'accès à la clé.
  const new();

  static const _name = 'history_key_v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<List<int>?> read() async {
    final encoded = await _storage.read(key: _name);
    return encoded == null ? null : base64Decode(encoded);
  }

  @override
  Future<void> write(List<int> key) =>
      _storage.write(key: _name, value: base64Encode(key));

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

/// Clé gardée en mémoire, pour les tests.
final class MemoryHistoryKeyStore implements HistoryKeyStore {
  List<int>? key;

  @override
  Future<List<int>?> read() async => key;

  @override
  Future<void> write(List<int> key) async => this.key = List.of(key);

  @override
  Future<void> delete() async => key = null;
}

/// Erreur de déchiffrement : clé différente ou donnée altérée.
final class HistoryDecryptionException implements Exception {
  const new();

  @override
  String toString() => 'HistoryDecryptionException';
}

/// Chiffrement authentifié AES-256-GCM des champs de l'historique.
///
/// Format : un octet de version, le nonce (12 octets), le texte chiffré et
/// l'étiquette d'authentification (16 octets). Les données associées lient
/// chaque valeur à sa vérification et à son champ : une valeur recopiée
/// dans une autre ligne ne se déchiffre pas.
final class HistoryCipher {
  new _(this._key);

  /// Ouvre le chiffrement avec la clé de [store], créée si besoin.
  static Future<HistoryCipher> open(HistoryKeyStore store) async {
    var bytes = await store.read();
    if (bytes == null || bytes.length != 32) {
      final key = await _algorithm.newSecretKey();
      bytes = await key.extractBytes();
      await store.write(bytes);
    }
    return HistoryCipher._(SecretKey(bytes));
  }

  static const _version = 1;
  static final _algorithm = AesGcm.with256bits();

  final SecretKey _key;

  /// Chiffre [plaintext] pour le champ [field] de la vérification [id].
  Future<Uint8List> encrypt(String plaintext, String id, String field) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
      aad: _aad(id, field),
    );
    return Uint8List.fromList([_version, ...box.concatenation()]);
  }

  /// Déchiffre [data] ; lève [HistoryDecryptionException] en cas d'échec.
  Future<String> decrypt(List<int> data, String id, String field) async {
    final overhead =
        1 + _algorithm.nonceLength + _algorithm.macAlgorithm.macLength;
    if (data.length < overhead || data.first != _version) {
      throw const HistoryDecryptionException();
    }
    try {
      final box = SecretBox.fromConcatenation(
        data.sublist(1),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: _key,
        aad: _aad(id, field),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const HistoryDecryptionException();
    } on FormatException {
      throw const HistoryDecryptionException();
    }
  }

  static List<int> _aad(String id, String field) =>
      utf8.encode('safelink-history/$id/$field');
}
