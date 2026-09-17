import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:ishamela/core/models/models.dart';

/// Resolve [relative] against [baseUrl] (trailing slash normalized).
String catalogUrl(String baseUrl, String relative) {
  final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  return Uri.parse(base).resolve(relative).toString();
}

/// HTTP access for the published catalog (SPEC-004).
class CatalogClient {
  CatalogClient(this.dio, {required this.baseUrl});

  final Dio dio;
  final String baseUrl;

  Future<CatalogManifest> fetchManifest({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final url = catalogUrl(baseUrl, 'catalog/catalog.json');
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );
    final raw = response.data;
    if (raw == null) {
      throw StateError('empty catalog.json');
    }
    return CatalogManifest.fromJson(
      jsonDecode(utf8.decode(raw)) as Map<String, dynamic>,
    );
  }

  Future<Uint8List> fetchBytes(String relativePath) async {
    final url = catalogUrl(baseUrl, relativePath);
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}
