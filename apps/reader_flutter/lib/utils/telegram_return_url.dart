import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

/// App URL Telegram should open after “Confirm my phone”.
///
/// - Web debug: current origin (`http://localhost:…/#/auth/telegram`)
/// - Release / native: production web app
String telegramAppReturnUrl() {
  const prod = 'https://app.felegemetsahft.com/#/auth/telegram';
  if (kIsWeb) {
    final origin = Uri.base.origin;
    // Local / LAN Flutter web → bounce back here after confirm.
    if (!kReleaseMode ||
        origin.contains('localhost') ||
        origin.contains('127.0.0.1')) {
      return '$origin/#/auth/telegram';
    }
    // Deployed Flutter web
    if (origin.contains('felegemetsahft.com')) {
      return '$origin/#/auth/telegram';
    }
  }
  // Native mobile/desktop builds: open production web continue route
  // (custom app scheme can replace this later).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    if (kReleaseMode) return prod;
    // Debug native still uses prod HTTPS so Telegram's redirect works;
    // local web is the usual local test path.
    return prod;
  }
  return prod;
}
