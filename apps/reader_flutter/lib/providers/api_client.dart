import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'session_notifier.dart';

/// Attaches the current access token and retries once after refresh on 401.
///
/// Uses [SessionNotifier] directly (not [Ref]) so async Dio callbacks stay valid
/// when the session updates and must not trigger [apiDioProvider] rebuilds.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required SessionNotifier sessionNotifier,
    required Dio dio,
  })  : _session = sessionNotifier,
        _dio = dio;

  final SessionNotifier _session;
  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final s = _session.currentSession;
    if (s != null) {
      options.headers['Authorization'] = 'Bearer ${s.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
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

    final ok = await _session.tryRefresh();
    if (!ok) {
      await _session.clear();
      return handler.next(err);
    }

    try {
      final session = _session.currentSession;
      final ro = err.requestOptions;
      if (session != null) {
        ro.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      final clone = await _dio.fetch<dynamic>(ro);
      return handler.resolve(clone);
    } catch (_) {
      return handler.next(err);
    }
  }
}

/// Authenticated API client. Does not rebuild when tokens refresh — the
/// interceptor reads the latest session from [sessionNotifierProvider.notifier].
final apiDioProvider = Provider<Dio>((ref) {
  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(sessionNotifier: sessionNotifier, dio: dio),
  );

  ref.onDispose(dio.close);
  return dio;
});
