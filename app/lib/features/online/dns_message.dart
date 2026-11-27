import 'dart:typed_data';

/// Requête et réponse DNS au format binaire (RFC 1035), réduites à ce dont
/// SafeLink a besoin : une question de type A et la lecture du code de
/// réponse, des adresses IPv4 et des « Extended DNS Errors » (RFC 8914).
abstract final class DnsMessage {
  /// Type A (adresse IPv4).
  static const typeA = 1;

  /// Type OPT (EDNS, RFC 6891).
  static const typeOpt = 41;

  /// Option EDNS « Extended DNS Error ».
  static const optionExtendedError = 15;

  /// Codes d'erreur étendus qui signalent un blocage par le résolveur :
  /// 15 « Blocked », 16 « Censored », 17 « Filtered ».
  static const blockingErrors = {15, 16, 17};

  /// Requête A pour [name] (en ASCII), avec EDNS pour recevoir les erreurs
  /// étendues. L'identifiant vaut 0, comme le recommande RFC 8484.
  static Uint8List query(String name) {
    final bytes = BytesBuilder()
      ..add([0, 0]) // identifiant
      ..add([0x01, 0x00]) // récursion demandée
      ..add([0, 1, 0, 0, 0, 0, 0, 1]); // 1 question, 1 enregistrement EDNS
    for (final label in name.split('.')) {
      if (label.isEmpty) continue;
      final codes = label.codeUnits;
      if (codes.length > 63 || codes.any((c) => c > 0x7f)) {
        throw ArgumentError.value(name, 'name', 'nom DNS invalide');
      }
      bytes
        ..addByte(codes.length)
        ..add(codes);
    }
    bytes
      ..addByte(0)
      ..add([0, typeA, 0, 1]) // type A, classe IN
      // Enregistrement OPT : nom racine, type 41, taille 1232, sans option.
      ..add([0, 0, typeOpt, 0x04, 0xd0, 0, 0, 0, 0, 0, 0]);
    return bytes.toBytes();
  }

  /// Lit une réponse ; lève [FormatException] si elle est mal formée.
  static DnsResponse parse(List<int> data) {
    // L'identifiant (2 octets) est ignoré.
    final reader = _Reader(Uint8List.fromList(data))..skip(2);
    final flags = reader.uint16();
    if (flags & 0x8000 == 0) {
      throw const FormatException('Ce n’est pas une réponse DNS.');
    }
    final questions = reader.uint16();
    final answers = reader.uint16();
    final authorities = reader.uint16();
    final additional = reader.uint16();
    for (var i = 0; i < questions; i++) {
      reader
        ..skipName()
        ..skip(4);
    }
    final addresses = <String>[];
    final errors = <int>{};
    for (var i = 0; i < answers + authorities + additional; i++) {
      reader.skipName();
      final type = reader.uint16();
      reader.skip(6); // classe et durée de vie
      final length = reader.uint16();
      final data = reader.bytes(length);
      if (i < answers && type == typeA && length == 4) {
        addresses.add(data.join('.'));
      }
      if (i >= answers + authorities && type == typeOpt) {
        errors.addAll(_extendedErrors(data));
      }
    }
    return DnsResponse(
      responseCode: flags & 0x0f,
      addresses: addresses,
      authorityCount: authorities,
      extendedErrors: errors,
    );
  }

  static Iterable<int> _extendedErrors(Uint8List options) sync* {
    final reader = _Reader(options);
    while (reader.remaining >= 4) {
      final code = reader.uint16();
      final length = reader.uint16();
      final value = reader.bytes(length);
      if (code == optionExtendedError && value.length >= 2) {
        yield value[0] << 8 | value[1];
      }
    }
  }
}

/// Réponse DNS lue.
final class DnsResponse {
  /// Crée une réponse.
  const new({
    required this.responseCode,
    required this.addresses,
    required this.authorityCount,
    required this.extendedErrors,
  });

  /// Code de réponse : 0 NOERROR, 3 NXDOMAIN…
  final int responseCode;

  /// Adresses IPv4 de la section réponse.
  final List<String> addresses;

  /// Nombre d'enregistrements dans la section autorité.
  final int authorityCount;

  /// Codes « Extended DNS Error » reçus.
  final Set<int> extendedErrors;

  /// Le nom existe (réponse sans erreur).
  bool get exists => responseCode == 0;

  /// Le nom n'existe pas (NXDOMAIN).
  bool get isNameError => responseCode == 3;

  /// Le résolveur filtrant a bloqué le nom : adresse `0.0.0.0`
  /// (Cloudflare) ou erreur étendue de blocage (Quad9 : 17 « Filtered »).
  bool get isBlocked =>
      addresses.contains('0.0.0.0') ||
      extendedErrors.any(DnsMessage.blockingErrors.contains);
}

final class _Reader {
  new(this._data);

  final Uint8List _data;
  int _offset = 0;

  int get remaining => _data.length - _offset;

  void _need(int count) {
    if (count < 0 || _offset + count > _data.length) {
      throw const FormatException('Réponse DNS tronquée.');
    }
  }

  void skip(int count) {
    _need(count);
    _offset += count;
  }

  int uint16() {
    _need(2);
    final value = _data[_offset] << 8 | _data[_offset + 1];
    _offset += 2;
    return value;
  }

  Uint8List bytes(int count) {
    _need(count);
    final value = Uint8List.sublistView(_data, _offset, _offset + count);
    _offset += count;
    return value;
  }

  /// Saute un nom, compressé ou non.
  void skipName() {
    for (var labels = 0; labels < 128; labels++) {
      _need(1);
      final length = _data[_offset];
      if (length == 0) {
        _offset += 1;
        return;
      }
      if (length & 0xc0 == 0xc0) {
        skip(2); // pointeur de compression : fin du nom
        return;
      }
      if (length & 0xc0 != 0) {
        throw const FormatException('Étiquette DNS inconnue.');
      }
      skip(1 + length);
    }
    throw const FormatException('Nom DNS trop long.');
  }
}
