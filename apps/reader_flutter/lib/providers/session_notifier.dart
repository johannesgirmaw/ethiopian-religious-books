import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';
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
    state = const AsyncData(null);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
