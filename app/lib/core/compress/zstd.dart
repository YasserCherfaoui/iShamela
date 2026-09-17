import 'dart:typed_data';

import 'package:zstandard/zstandard.dart';

/// Decompresses zstd payloads (SPEC-004 Task 0: `zstandard` plugin).
abstract class ZstdDecompressor {
  Future<Uint8List> decompress(Uint8List input);
}

class PluginZstdDecompressor implements ZstdDecompressor {
  PluginZstdDecompressor([Zstandard? client]) : _client = client ?? Zstandard();

  final Zstandard _client;

  @override
  Future<Uint8List> decompress(Uint8List input) async {
    final out = await _client.decompress(input);
    if (out == null) {
      throw StateError('zstd decompress returned null');
    }
    return out;
  }
}

/// Test double that returns a fixed payload or delegates to a callback.
class FakeZstdDecompressor implements ZstdDecompressor {
  FakeZstdDecompressor(this._handler);

  final Future<Uint8List> Function(Uint8List input) _handler;

  @override
  Future<Uint8List> decompress(Uint8List input) => _handler(input);
}
