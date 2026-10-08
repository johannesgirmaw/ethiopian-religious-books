import 'package:flutter/foundation.dart' show kIsWeb;

const androidApkFileName = 'felege-metsahft.apk';

const _publicApkUrl =
    'https://felegemetsahft.com/downloads/$androidApkFileName';

/// APK URL for the in-app install prompt.
///
/// On the production web origin this is same-host (`/native-apps/…`) so the
/// download can report progress without a CORS round-trip. Everywhere else
/// it falls back to the public landing URL.
String androidApkDownloadUrl() {
  if (!kIsWeb) return _publicApkUrl;
  final origin = Uri.base.origin;
  if (Uri.base.host == 'app.felegemetsahft.com') {
    return '$origin/native-apps/$androidApkFileName';
  }
  return _publicApkUrl;
}
