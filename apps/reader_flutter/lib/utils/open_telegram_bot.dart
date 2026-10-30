import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Opens the Telegram **app** (mobile or desktop) for [username] with a
/// `/start` payload. Falls back to `https://t.me/…` when `tg://` is unavailable.
Future<bool> openTelegramBot({
  required String username,
  required String startPayload,
  String? httpsFallback,
}) async {
  final clean = username.replaceAll('@', '').trim();
  if (clean.isEmpty || startPayload.isEmpty) return false;

  final tg = Uri.parse('tg://resolve?domain=$clean&start=$startPayload');
  final https = Uri.parse(
    httpsFallback?.trim().isNotEmpty == true
        ? httpsFallback!.trim()
        : 'https://t.me/$clean?start=$startPayload',
  );

  // Prefer the native scheme so mobile opens Telegram Mobile and desktop
  // opens Telegram Desktop instead of Telegram Web in the browser.
  if (await _tryLaunch(tg)) return true;

  // Some desktop browsers block tg:// from canLaunch; try launch anyway.
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    try {
      final ok = await launchUrl(tg, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}
  }

  return _tryLaunch(https);
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
