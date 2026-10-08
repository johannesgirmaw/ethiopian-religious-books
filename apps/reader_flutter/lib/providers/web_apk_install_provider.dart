import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/android_apk_url.dart';
import '../utils/web_blob_saver_stub.dart'
    if (dart.library.html) '../utils/web_blob_saver_web.dart';

const _dismissedKey = 'web_apk_install_dismissed';

/// True on Flutter web when the browser reports an Android user agent.
bool get showWebAndroidInstallPrompt =>
    kIsWeb && defaultTargetPlatform == TargetPlatform.android;

enum WebApkInstallPhase { idle, downloading, done, error }

class WebApkInstallState {
  const WebApkInstallState({
    this.dismissed = false,
    this.phase = WebApkInstallPhase.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.error,
  });

  final bool dismissed;
  final WebApkInstallPhase phase;
  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final String? error;

  double? get fraction {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  WebApkInstallState copyWith({
    bool? dismissed,
    WebApkInstallPhase? phase,
    int? receivedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    String? error,
    bool clearError = false,
  }) {
    return WebApkInstallState(
      dismissed: dismissed ?? this.dismissed,
      phase: phase ?? this.phase,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WebApkInstallNotifier extends Notifier<WebApkInstallState> {
  CancelToken? _cancel;
  DateTime? _startedAt;
  var _alive = true;

  @override
  WebApkInstallState build() {
    _alive = true;
    _restoreDismissed();
    ref.onDispose(() {
      _alive = false;
      _cancel?.cancel();
    });
    return const WebApkInstallState();
  }

  Future<void> _restoreDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_alive) return;
    if (prefs.getBool(_dismissedKey) == true) {
      state = state.copyWith(dismissed: true);
    }
  }

  Future<void> dismiss() async {
    _cancel?.cancel();
    _cancel = null;
    state = state.copyWith(
      dismissed: true,
      phase: WebApkInstallPhase.idle,
      receivedBytes: 0,
      totalBytes: 0,
      bytesPerSecond: 0,
      clearError: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  Future<void> startDownload() async {
    if (state.phase == WebApkInstallPhase.downloading) return;
    _cancel?.cancel();
    _cancel = CancelToken();
    _startedAt = DateTime.now();
    state = state.copyWith(
      phase: WebApkInstallPhase.downloading,
      receivedBytes: 0,
      totalBytes: 0,
      bytesPerSecond: 0,
      clearError: true,
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
        responseType: ResponseType.bytes,
      ),
    );

    try {
      final res = await dio.get<List<int>>(
        androidApkDownloadUrl(),
        cancelToken: _cancel,
        onReceiveProgress: (received, total) {
          if (!_alive) return;
          final started = _startedAt;
          var speed = 0.0;
          if (started != null) {
            final secs =
                DateTime.now().difference(started).inMilliseconds / 1000.0;
            if (secs > 0.05) speed = received / secs;
          }
          state = state.copyWith(
            receivedBytes: received,
            totalBytes: total > 0 ? total : state.totalBytes,
            bytesPerSecond: speed,
          );
        },
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('empty apk');
      }
      saveBytesToDevice(
        filename: androidApkFileName,
        bytes: bytes,
        mimeType: 'application/vnd.android.package-archive',
      );
      if (!_alive) return;
      state = state.copyWith(
        phase: WebApkInstallPhase.done,
        receivedBytes: bytes.length,
        totalBytes: bytes.length,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (!_alive) return;
      state = state.copyWith(phase: WebApkInstallPhase.error, error: e.message);
    } catch (_) {
      if (!_alive) return;
      state = state.copyWith(phase: WebApkInstallPhase.error);
    }
  }
}

final webApkInstallProvider =
    NotifierProvider<WebApkInstallNotifier, WebApkInstallState>(
      WebApkInstallNotifier.new,
    );
