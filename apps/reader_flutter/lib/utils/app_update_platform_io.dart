import 'dart:io';

/// iOS and web cannot replace the running app from inside it.
bool get supportsInAppUpdate =>
    Platform.isAndroid ||
    Platform.isMacOS ||
    Platform.isWindows ||
    Platform.isLinux;

/// Key in `releases.json` for this device.
String? get currentUpdatePlatform {
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return null;
}
