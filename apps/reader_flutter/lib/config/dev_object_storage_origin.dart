import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Host port for MinIO on the machine running Docker (see `infra/.env` MINIO_API_PORT).
const int _minioDevPort = int.fromEnvironment('MINIO_DEV_PORT', defaultValue: 19000);

/// Reachable MinIO origin for this device in local dev (same host as API, MinIO port).
String? devMinioOriginBase() {
  if (!kDebugMode) {
    return null;
  }
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (base == null || !base.hasScheme || base.host.isEmpty) {
    return null;
  }
  if (!_looksLikeLocalDevApiHost(base.host)) {
    return null;
  }
  var host = base.host;
  if (host.toLowerCase() == 'localhost') {
    host = '127.0.0.1';
  }
  return '${base.scheme}://$host:$_minioDevPort';
}

/// DEBUG builds only: tells Django (when DEBUG) to presign S3 URLs for this MinIO origin
/// so downloads work from emulators/devices where `localhost` in the URL would be wrong.
Map<String, String> devObjectStorageOriginHeaders() {
  final origin = devMinioOriginBase();
  if (origin == null) {
    return const {};
  }
  return {'X-Dev-S3-Origin': origin};
}

/// Rewrites presigned MinIO URLs that still point at `localhost` to a host this device can reach.
String rewriteDevObjectStorageUrl(String url) {
  final origin = devMinioOriginBase();
  if (origin == null) {
    return url;
  }
  final parsed = Uri.tryParse(url);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return url;
  }
  final host = parsed.host.toLowerCase();
  if (!_isLoopbackOrDockerStorageHost(host)) {
    return url;
  }
  final target = Uri.parse(origin);
  return parsed
      .replace(
        scheme: target.scheme,
        host: target.host,
        port: target.port,
      )
      .toString();
}

bool _isLoopbackOrDockerStorageHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == 'minio';
}

bool _looksLikeLocalDevApiHost(String host) {
  final h = host.toLowerCase();
  if (h == '127.0.0.1' || h == 'localhost' || h == '10.0.2.2' || h == '::1') {
    return true;
  }
  if (RegExp(r'^192\.168\.').hasMatch(h)) {
    return true;
  }
  if (RegExp(r'^10\.').hasMatch(h)) {
    return true;
  }
  return RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(h);
}
