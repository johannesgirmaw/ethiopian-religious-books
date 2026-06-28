import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../security/book_crypto.dart';
import '../storage/secure_book_store.dart';
import '../storage/token_storage.dart';

class Session {
  Session({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile? user;
}

class SessionNotifier extends AsyncNotifier<Session?> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  /// Current session for Dio interceptors and other non-widget callers.
  Session? get currentSession => state.valueOrNull;

  @override
  Future<Session?> build() async {
    final access = await _storage.readAccess();
    final refresh = await _storage.readRefresh();
    if (access == null || refresh == null) return null;
    final uj = await _storage.readUserJson();
    UserProfile? user;
    if (uj != null) {
      try {
        user = UserProfile.fromJson(jsonDecode(uj) as Map<String, dynamic>);
      } catch (_) {}
    }
    return Session(accessToken: access, refreshToken: refresh, user: user);
  }

  Future<void> persistFromAuthResponse(Map<String, dynamic> data) async {
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    final userMap = data['user'] as Map<String, dynamic>?;
    final userJson = userMap == null ? null : jsonEncode(userMap);
    await _storage.saveSession(
      accessToken: access,
      refreshToken: refresh,
      userJson: userJson,
    );
    state = AsyncData(
      Session(
        accessToken: access,
        refreshToken: refresh,
        user: userMap == null ? null : UserProfile.fromJson(userMap),
      ),
    );
  }

  /// Replaces the stored tokens while keeping the current user (used after a
  /// password change, where the server rotates every session and hands back a
  /// fresh token pair so this device stays signed in).
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final cur = state.valueOrNull;
    await _storage.updateAccess(accessToken, refresh: refreshToken);
    state = AsyncData(
      Session(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: cur?.user,
      ),
    );
  }

  Future<bool> tryRefresh() async {
    final cur = state.valueOrNull;
    if (cur == null) return false;
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
        ),
      );
      final res = await dio.post<Map<String, dynamic>>(
        'auth/refresh',
        data: {'refresh_token': cur.refreshToken},
      );
      final d = res.data!;
      final access = d['access_token'] as String;
      final refresh = d['refresh_token'] as String? ?? cur.refreshToken;
      await _storage.updateAccess(access, refresh: refresh);
      state = AsyncData(
        Session(
          accessToken: access,
          refreshToken: refresh,
          user: cur.user,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    await _storage.clear();
    // Drop the encrypted offline library and its device key so a different user
    // on this device cannot read the previous user's downloaded books.
    try {
      await SecureBookStore.clearAll();
      await BookCrypto.wipeMasterKey();
    } catch (_) {
      // Best-effort: never block sign-out on vault cleanup.
    }
    state = const AsyncData(null);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
