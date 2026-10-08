// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Drop browser-cached PDF blobs on logout so the next account on this profile
/// cannot reopen a previous user's books from Cache Storage.
Future<void> clearPdfFullCache() async {
  try {
    final caches = html.window.caches;
    if (caches == null) return;
    await caches.delete('fm-pdf-full-v2');
    await caches.delete('fm-pdf-full-v1');
  } catch (_) {
    // Best-effort: never block sign-out.
  }
}
