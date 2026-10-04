import 'package:dio/dio.dart';

import 'package:ishamela/core/sync/token_store.dart';

/// Attaches the access token and retries once after a shared refresh (SPEC-028 §8).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokens,
    required this.dio,
    required this.refreshPath,
    required this.onSignedOut,
  });

  final TokenStore tokens;
  final Dio dio;
  final String refreshPath;
  final Future<void> Function() onSignedOut;

  Future<bool>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    final access = await tokens.readAccess();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final options = err.requestOptions;
    if (status != 401 ||
        options.extra['skipAuth'] == true ||
        options.extra['retried'] == true) {
      if (status == 401 && options.extra['skipAuth'] != true) {
        await tokens.clear();
        await onSignedOut();
      }
      handler.next(err);
      return;
    }
    final ok = await (_refreshing ??= _refresh().whenComplete(() {
      _refreshing = null;
    }));
    if (!ok) {
      handler.next(err);
      return;
    }
    try {
      options.extra['retried'] = true;
      final access = await tokens.readAccess();
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retry) {
      handler.next(retry);
    }
  }

  Future<bool> _refresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      await tokens.clear();
      await onSignedOut();
      return false;
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': refresh},
        options: Options(extra: const {'skipAuth': true}),
      );
      final body = response.data;
      final access = body?['accessToken'] as String?;
      final next = body?['refreshToken'] as String?;
      if (access == null || next == null) {
        await tokens.clear();
        await onSignedOut();
        return false;
      }
      await tokens.write(access: access, refresh: next);
      return true;
    } catch (_) {
      await tokens.clear();
      await onSignedOut();
      return false;
    }
  }
}
