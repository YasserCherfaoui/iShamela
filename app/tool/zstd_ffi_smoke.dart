import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _GetFrameContentSizeC = Uint64 Function(Pointer<Uint8>, UintPtr);
typedef _GetFrameContentSizeDart = int Function(Pointer<Uint8>, int);
typedef _DecompressC = UintPtr Function(
  Pointer<Uint8>,
  UintPtr,
  Pointer<Uint8>,
  UintPtr,
);
typedef _DecompressDart = int Function(Pointer<Uint8>, int, Pointer<Uint8>, int);
typedef _IsErrorC = Uint32 Function(UintPtr);
typedef _IsErrorDart = int Function(int);

void main() {
  final lib = DynamicLibrary.open('/opt/homebrew/lib/libzstd.dylib');
  final getSize = lib.lookupFunction<_GetFrameContentSizeC, _GetFrameContentSizeDart>(
    'ZSTD_getFrameContentSize',
  );
  final decompress = lib.lookupFunction<_DecompressC, _DecompressDart>(
    'ZSTD_decompress',
  );
  final isError = lib.lookupFunction<_IsErrorC, _IsErrorDart>('ZSTD_isError');

  final compressed =
      File('/Users/mac/Projects/iShamela/data/dist/book_1.isb').readAsBytesSync();
  final src = calloc<Uint8>(compressed.length);
  src.asTypedList(compressed.length).setAll(0, compressed);

  var size = getSize(src, compressed.length);
  // ZSTD_CONTENTSIZE_UNKNOWN == (0ULL-1)
  if (size == -1 || size == 0xFFFFFFFFFFFFFFFF) {
    size = compressed.length * 16;
    stdout.writeln('unknown frame size; trying capacity=$size');
  }
  final dst = calloc<Uint8>(size);
  final result = decompress(dst, size, src, compressed.length);
  stdout.writeln('result=$result isError=${isError(result)}');
  if (isError(result) == 0) {
    final out = dst.asTypedList(result);
    stdout.writeln(String.fromCharCodes(out.take(15)));
    stdout.writeln('OK len=$result');
  }
  calloc.free(src);
  calloc.free(dst);
}
