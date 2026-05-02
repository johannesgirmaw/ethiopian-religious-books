import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Host port for MinIO on the machine running Docker (see `infra/.env` MINIO_API_PORT).
const int _minioDevPort = int.fromEnvironment('MINIO_DEV_PORT', defaultValue: 19000);

/// DEBUG builds only: tells Django (when DEBUG) to presign S3 URLs for this MinIO origin
/// so downloads work from emulators/devices where `localhost` in the URL would be wrong.
Map<String, String> devObjectStorageOriginHeaders() {
  if (!kDebugMode) {
    return const {};
  }
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (base == null || !base.hasScheme || base.host.isEmpty) {
    return const {};
  }
  if (!_looksLikeLocalDevApiHost(base.host)) {
    return const {};
  }
  var host = base.host;
  if (host.toLowerCase() == 'localhost') {
    host = '127.0.0.1';
  }
  return {'X-Dev-S3-Origin': '${base.scheme}://$host:$_minioDevPort'};
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
