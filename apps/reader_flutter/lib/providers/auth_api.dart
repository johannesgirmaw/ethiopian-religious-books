import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';

/// Centralised auth endpoints.
///
/// Unauthenticated calls (login, register, forgot/reset password) use a bare
/// [Dio] so they never pass through the access-token interceptor. The
/// authenticated change-password call reuses [apiDioProvider].
class AuthApi {
  AuthApi(this._ref);

  final Ref _ref;

  Dio _public() => Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
          headers: const {'Accept': 'application/json'},
        ),
      );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _public().post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await _public().post<Map<String, dynamic>>(
      'auth/register',
      data: {
        'email': email,
        'password': password,
        'display_name':
            (displayName == null || displayName.isEmpty) ? null : displayName,
      },
    );
    return res.data!;
  }

  /// Requests a reset code. The server always responds 200 (no account
  /// enumeration), so a successful return does not imply the email exists.
  Future<void> forgotPassword({required String email}) async {
    await _public().post<Map<String, dynamic>>(
      'auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _public().post<Map<String, dynamic>>(
      'auth/reset-password',
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
  }

  /// Changes the signed-in user's password and returns freshly-issued tokens
  /// (the server rotates every session on change).
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final dio = _ref.read(apiDioProvider);
    final res = await dio.post<Map<String, dynamic>>(
      'auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return res.data!;
  }

  /// Starts Telegram bot OTP. [purpose] is `login` or `phone_link`.
  Future<Map<String, dynamic>> telegramInitiate({
    required String phone,
    required String purpose,
  }) async {
    final Dio dio =
        purpose == 'phone_link' ? _ref.read(apiDioProvider) : _public();
    final res = await dio.post<Map<String, dynamic>>(
      'auth/telegram/initiate',
      data: {'phone': phone, 'purpose': purpose},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> telegramVerify({
    required String phone,
    required String code,
    required String purpose,
  }) async {
    final Dio dio =
        purpose == 'phone_link' ? _ref.read(apiDioProvider) : _public();
    final res = await dio.post<Map<String, dynamic>>(
      'auth/telegram/verify',
      data: {'phone': phone, 'code': code, 'purpose': purpose},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> telegramComplete({
    required String phone,
    required String code,
    required String email,
    String? password,
    String? displayName,
  }) async {
    final res = await _public().post<Map<String, dynamic>>(
      'auth/telegram/complete',
      data: {
        'phone': phone,
        'code': code,
        'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
      },
    );
    return res.data!;
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref));
