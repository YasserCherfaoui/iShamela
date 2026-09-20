import 'dart:typed_data';

/// Decompresses zstd payloads (SPEC-004 Task 0).
abstract class ZstdDecompressor {
  Future<Uint8List> decompress(Uint8List input);
}

/// Web has no `zstandard_*` FFI plugin — catalog uses a plain `.sqlite` asset.
class PluginZstdDecompressor implements ZstdDecompressor {
  PluginZstdDecompressor();

  @override
  Future<Uint8List> decompress(Uint8List input) async {
    throw UnsupportedError(
      'zstd decompress is not available on web; use the plain catalog asset',
    );
  }
}

/// Test double that returns a fixed payload or delegates to a callback.
class FakeZstdDecompressor implements ZstdDecompressor {
  FakeZstdDecompressor(this._handler);

  final Future<Uint8List> Function(Uint8List input) _handler;

  @override
  Future<Uint8List> decompress(Uint8List input) => _handler(input);
}
