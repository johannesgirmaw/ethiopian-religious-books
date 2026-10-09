import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Opens the public Telegram support group in the browser / Telegram app.
Future<bool> openTelegramSupport() {
  return launchUrl(
    Uri.parse(AppConfig.telegramSupportUrl),
    mode: LaunchMode.externalApplication,
  );
}
