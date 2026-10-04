import 'package:dio/dio.dart';

import 'package:ishamela/core/sync/sync_drain.dart';

class ProjectSession {
  const ProjectSession({
    required this.accessToken,
    required this.refreshToken,
    required this.deviceId,
  });

  final String accessToken;
  final String refreshToken;
  final String deviceId;
}

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;
}

/// Stable `error.code` from the project API.
class ApiAuthException implements Exception {
  ApiAuthException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => 'ApiAuthException($code)';
}

ApiAuthException apiAuthException(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final body = data['error'];
    if (body is Map && body['code'] is String) {
      return ApiAuthException(
        body['code'] as String,
        body['message'] as String? ?? '',
      );
    }
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return ApiAuthException('network-request-failed');
  }
  return ApiAuthException('HTTP_ERROR', error.message ?? '');
}

/// SPEC-027 client used by the outbox drain.
class IshamelaApi implements SyncTransport {
  IshamelaApi(this._dio, {required this.baseUrl});

  final Dio _dio;
  final String baseUrl;

  String get _root => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  @override
  String get progressUrl => '$_root/v1/progress';

  Future<ProjectSession> signInGoogle({
    required String idToken,
    required Map<String, Object?> device,
  }) {
    return _authResult('$_root/v1/auth/google', {
      'idToken': idToken,
      'device': device,
    });
  }

  Future<ProjectSession> signInApple({
    required String identityToken,
    String? authorizationCode,
    required Map<String, Object?> device,
  }) {
    return _authResult('$_root/v1/auth/apple', {
      'identityToken': identityToken,
      if (authorizationCode != null) 'authorizationCode': authorizationCode,
      'device': device,
    });
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>(
      '$_root/v1/auth/logout',
      data: {'refreshToken': refreshToken},
      options: Options(extra: const {'skipAuth': true}),
    );
  }

  Future<void> deleteMe() async {
    try {
      await _dio.delete<void>('$_root/v1/me');
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
  }

  Future<void> requestOtp(String email) async {
    try {
      await _dio.post<void>(
        '$_root/v1/auth/otp/request',
        data: {'email': email},
        options: Options(extra: const {'skipAuth': true}),
      );
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
  }

  Future<ProjectSession> verifyOtp({
    required String email,
    required String code,
    required Map<String, Object?> device,
  }) {
    return _authResult('$_root/v1/auth/otp/verify', {
      'email': email,
      'code': code,
      'device': device,
    });
  }

  Future<ApiProfile> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_root/v1/me');
      final body = response.data ?? const <String, dynamic>{};
      final id = body['id'] as String?;
      if (id == null || id.isEmpty) {
        throw ApiAuthException('UNAUTHORIZED');
      }
      return ApiProfile(
        id: id,
        email: body['email'] as String?,
        displayName: body['displayName'] as String?,
      );
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
  }

  Future<ApiProfile> patchMe(String displayName) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_root/v1/me',
        data: {'displayName': displayName},
      );
      final body = response.data ?? const <String, dynamic>{};
      return ApiProfile(
        id: body['id'] as String? ?? '',
        email: body['email'] as String?,
        displayName: body['displayName'] as String?,
      );
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
  }

  Future<void> registerDevice({
    required String platform,
    required String appVersion,
  }) async {
    try {
      await _dio.post<void>(
        '$_root/v1/devices/register',
        data: {'platform': platform, 'appVersion': appVersion},
      );
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
  }

  Future<ProjectSession> _authResult(
    String url,
    Map<String, Object?> data,
  ) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        url,
        data: data,
        options: Options(extra: const {'skipAuth': true}),
      );
    } on DioException catch (error) {
      throw apiAuthException(error);
    }
    final body = response.data ?? const <String, dynamic>{};
    final access = body['accessToken'] as String?;
    final refresh = body['refreshToken'] as String?;
    final device = body['device'];
    final deviceId = device is Map ? device['id'] as String? : null;
    if (access == null || refresh == null || !isDeviceUuid(deviceId)) {
      throw StateError('Auth response is missing tokens');
    }
    return ProjectSession(
      accessToken: access,
      refreshToken: refresh,
      deviceId: deviceId!,
    );
  }

  @override
  Future<void> postProgress(
    List<Map<String, Object?>> items, {
    required Duration timeout,
  }) async {
    await _dio.post<void>(
      '$_root/v1/progress',
      data: items,
      options: _options(timeout),
    );
  }

  @override
  Future<PushBatchResult> push(
    List<Map<String, Object?>> changes, {
    required Duration timeout,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_root/v1/sync/push',
      data: {'changes': changes},
      options: _options(timeout),
    );
    final body = response.data ?? const <String, dynamic>{};
    final applied = <String>{};
    final stale = <String>{};
    final rejected = <String, String>{};
    for (final row in _list(body['applied'])) {
      applied.add(changeKey(row['table'] as String?, row['key'] as String?));
    }
    for (final row in _list(body['rejected'])) {
      final key = changeKey(row['table'] as String?, row['key'] as String?);
      final reason = row['reason'] as String? ?? 'REJECTED';
      if (reason == 'STALE') {
        stale.add(key);
      } else {
        rejected[key] = reason;
      }
    }
    return PushBatchResult(
      appliedKeys: applied,
      staleKeys: stale,
      rejected: rejected,
    );
  }

  @override
  Future<PullBatch> pull({
    required int since,
    required Duration timeout,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_root/v1/sync/pull',
      queryParameters: {'since': since, 'limit': changeBatch},
      options: _options(timeout),
    );
    final body = response.data ?? const <String, dynamic>{};
    final changes = <PulledChange>[];
    for (final row in _list(body['changes'])) {
      final record = row['record'];
      changes.add(
        PulledChange(
          table: row['table'] as String? ?? '',
          record: record is Map
              ? Map<String, Object?>.from(record)
              : const <String, Object?>{},
        ),
      );
    }
    return PullBatch(
      changes: changes,
      nextCursor: (body['nextCursor'] as num?)?.toInt() ?? since,
      hasMore: body['hasMore'] == true,
    );
  }

  Options _options(Duration timeout) =>
      Options(sendTimeout: timeout, receiveTimeout: timeout);

  List<Map<String, dynamic>> _list(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
}
