import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> enterBrowserFullscreen() async {
  final el = web.document.documentElement;
  if (el == null) return;
  try {
    await el.requestFullscreen().toDart;
  } catch (_) {
    // Browser may deny without a user gesture or unsupported.
  }
}

Future<void> exitBrowserFullscreen() async {
  if (web.document.fullscreenElement == null) return;
  try {
    await web.document.exitFullscreen().toDart;
  } catch (_) {}
}
