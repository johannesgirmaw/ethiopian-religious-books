import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_release.dart';
import '../utils/app_update_platform.dart';
import '../utils/app_version.dart';

/// The published installer when it is newer than this build. Null on web,
/// iOS, while offline, and when this install is already current.
final appUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  if (!supportsInAppUpdate) return null;
  final platform = currentUpdatePlatform;
  if (platform == null) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    final local = AppVersion.fromPackage(
      version: info.version,
      buildNumber: info.buildNumber,
    );
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
      ),
    );
    final response = await dio.get<String>(
      appReleasesUrl,
      queryParameters: {'ts': DateTime.now().millisecondsSinceEpoch},
    );
    final decoded = jsonDecode(response.data ?? '');
    return newerReleaseFromJson(decoded, platform, local);
  } catch (_) {
    return null;
  }
});
