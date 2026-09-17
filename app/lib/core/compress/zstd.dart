import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Decompresses zstd payloads (SPEC-004 Task 0).
///
/// Uses the native lib shipped by the `zstandard` platform plugins (linked into
/// the app), but **not** `Zstandard().decompress` — that API sizes the output
/// buffer as `compressed.length * 20`, which is too small for level-19 frames
/// when the frame omits content size (Python `copy_stream` without a pledge).
abstract class ZstdDecompressor {
  Future<Uint8List> decompress(Uint8List input);
}

/// FFI decompressor against the embedded `zstandard_*` native library.
class PluginZstdDecompressor implements ZstdDecompressor {
  PluginZstdDecompressor();

  static DynamicLibrary? _lib;
  static _ZstdFns? _fns;

  static _ZstdFns get _api {
    final existing = _fns;
    if (existing != null) return existing;
    final lib = _lib ??= _openZstdLib();
    final api = _ZstdFns(lib);
    _fns = api;
    return api;
  }

  @override
  Future<Uint8List> decompress(Uint8List input) async {
    if (input.isEmpty) {
      throw StateError('zstd decompress: empty input');
    }
    return _decompressSync(input);
  }

  Uint8List _decompressSync(Uint8List input) {
    final api = _api;
    final src = malloc<Uint8>(input.length);
    try {
      src.asTypedList(input.length).setAll(0, input);
      final hinted = api.getFrameContentSize(src.cast(), input.length);
      // ZSTD_CONTENTSIZE_ERROR = (0ULL - 2), ZSTD_CONTENTSIZE_UNKNOWN = (0ULL - 1)
      const unknown = 0xFFFFFFFFFFFFFFFF;
      const error = 0xFFFFFFFFFFFFFFFE;
      var capacity = input.length * 32;
      if (hinted != unknown && hinted != error && hinted > 0 && hinted < unknown) {
        capacity = hinted;
      }
      // Grow on dstSize_tooSmall (error code typically negative when viewed as
      // signed; ZSTD_isError catches all error codes).
      for (var attempt = 0; attempt < 8; attempt++) {
        final dst = malloc<Uint8>(capacity);
        try {
          final n = api.decompress(dst.cast(), capacity, src.cast(), input.length);
          if (api.isError(n) == 0) {
            return Uint8List.fromList(dst.asTypedList(n));
          }
          // dstSize_tooSmall → grow; anything else → fail.
          final code = n;
          capacity = capacity < 1024 * 1024 ? capacity * 4 : capacity * 2;
          if (attempt == 7) {
            throw StateError('zstd decompress failed (code=$code)');
          }
        } finally {
          malloc.free(dst);
        }
      }
      throw StateError('zstd decompress failed');
    } finally {
      malloc.free(src);
    }
  }
}

DynamicLibrary _openZstdLib() {
  if (Platform.isMacOS) {
    return DynamicLibrary.open('zstandard_macos.framework/zstandard_macos');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.open('zstandard_ios.framework/zstandard_ios');
  }
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libzstandard_android.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('zstandard_windows.dll');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libzstandard_linux.so');
  }
  throw UnsupportedError('zstd: unsupported platform ${Platform.operatingSystem}');
}

class _ZstdFns {
  _ZstdFns(DynamicLibrary lib)
      : getFrameContentSize = lib.lookupFunction<_GetFrameSizeC, _GetFrameSizeDart>(
          'ZSTD_getFrameContentSize',
        ),
        decompress = lib.lookupFunction<_DecompressC, _DecompressDart>(
          'ZSTD_decompress',
        ),
        isError = lib.lookupFunction<_IsErrorC, _IsErrorDart>('ZSTD_isError');

  final _GetFrameSizeDart getFrameContentSize;
  final _DecompressDart decompress;
  final _IsErrorDart isError;
}

typedef _GetFrameSizeC = Uint64 Function(Pointer<Void>, UintPtr);
typedef _GetFrameSizeDart = int Function(Pointer<Void>, int);
typedef _DecompressC = UintPtr Function(
  Pointer<Void>,
  UintPtr,
  Pointer<Void>,
  UintPtr,
);
typedef _DecompressDart = int Function(Pointer<Void>, int, Pointer<Void>, int);
typedef _IsErrorC = Uint32 Function(UintPtr);
typedef _IsErrorDart = int Function(int);

/// Test double that returns a fixed payload or delegates to a callback.
class FakeZstdDecompressor implements ZstdDecompressor {
  FakeZstdDecompressor(this._handler);

  final Future<Uint8List> Function(Uint8List input) _handler;

  @override
  Future<Uint8List> decompress(Uint8List input) => _handler(input);
}
