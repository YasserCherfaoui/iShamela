import 'package:dio/dio.dart';

/// Shared Dio factory for catalog and bundle downloads (SPEC-004).
Dio createAppDio() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
