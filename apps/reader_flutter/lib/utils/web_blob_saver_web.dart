import 'dart:html' as html;

/// Triggers a browser file download from in-memory bytes (Flutter web).
void saveBytesToDevice({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
