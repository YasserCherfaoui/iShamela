import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Resumable Range GET for `.isb` bundles (SPEC-004).
class BundleDownloader {
  BundleDownloader(this.dio);

  final Dio dio;

  /// Streams [url] into [dest], appending when [existingBytes] > 0 and the
  /// server returns 206. Returns total bytes written (file length).
  Future<int> downloadToFile({
    required String url,
    required File dest,
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
    final sink = dest.openWrite(
      mode: response.statusCode == 206 ? FileMode.append : FileMode.write,
    );
    var done = response.statusCode == 206 ? existingBytes : 0;
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        done += chunk.length;
        onProgress?.call(done);
      }
    } finally {
      await sink.close();
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
