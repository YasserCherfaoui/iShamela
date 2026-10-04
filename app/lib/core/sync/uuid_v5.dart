import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Namespace for deterministic local→server row ids (SPEC-028 sign-in replay).
const ishamelaIdNamespace = 'a3e1c8b0-6f24-4c1a-9d55-0b7e2f4a91c3';

String uuidV5(String namespace, String name) {
  final ns = _uuidBytes(namespace);
  final digest = sha1.convert(<int>[...ns, ...utf8.encode(name)]).bytes;
  final bytes = Uint8List.fromList(digest.take(16).toList());
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return _formatUuid(bytes);
}

/// Random UUID for this install's device id until the server confirms it.
String uuidV4() {
  final random = Random.secure();
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = random.nextInt(256);
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return _formatUuid(bytes);
}

String _formatUuid(Uint8List bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Uint8List _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
