import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'session_notifier.dart';

/// Authenticated API client; recreates when [sessionNotifierProvider] changes.
final apiDioProvider = Provider<Dio>((ref) {
  ref.watch(sessionNotifierProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final s = ref.read(sessionNotifierProvider).valueOrNull;
        if (s != null) {
          options.headers['Authorization'] = 'Bearer ${s.accessToken}';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        final response = err.response;
        if (response?.statusCode != 401) {
          return handler.next(err);
        }
        final path = err.requestOptions.path;
        if (path.contains('auth/login') ||
            path.contains('auth/register') ||
            path.contains('auth/refresh')) {
          return handler.next(err);
        }
        final notifier = ref.read(sessionNotifierProvider.notifier);
        final ok = await notifier.tryRefresh();
        if (!ok) {
          await notifier.clear();
          return handler.next(err);
        }
        try {
          final session = ref.read(sessionNotifierProvider).valueOrNull;
          final ro = err.requestOptions;
          if (session != null) {
            ro.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          final clone = await dio.fetch<dynamic>(ro);
          return handler.resolve(clone);
        } catch (e) {
          return handler.next(err);
        }
      },
    ),
  );

  return dio;
});
