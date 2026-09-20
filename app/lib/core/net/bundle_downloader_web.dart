import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:ishamela/core/db/sqlite_api_web.dart';
import 'package:ishamela/core/db/web_sqlite.dart';

/// Resumable Range GET into IndexedDB VFS (SPEC-021).
class BundleDownloader {
  BundleDownloader(this.dio);

  final Dio dio;

  Future<int> downloadToFile({
    required String url,
    required String destPath,
    required int existingBytes,
    required CancelToken cancelToken,
    void Function(int bytesDone)? onProgress,
  }) async {
    final headers = <String, dynamic>{};
    if (existingBytes > 0) {
      headers['Range'] = 'bytes=$existingBytes-';
    }
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        validateStatus: (s) => s != null && (s == 200 || s == 206),
      ),
      cancelToken: cancelToken,
    );

    final fs = WebSqlite.vfs;
    const flags = SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE;
    final opened = fs.xOpen(Sqlite3Filename(destPath), flags);
    final file = opened.file;
    var done = response.statusCode == 206 ? existingBytes : 0;
    try {
      if (response.statusCode != 206) {
        file.xTruncate(0);
        done = 0;
      }
      await for (final chunk in response.data!.stream) {
        final bytes = Uint8List.fromList(chunk);
        file.xWrite(bytes, done);
        done += bytes.length;
        onProgress?.call(done);
      }
    } finally {
      file.xClose();
      await fs.flush();
    }
    return done;
  }

  Future<Uint8List> getAllBytes(String url) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}
