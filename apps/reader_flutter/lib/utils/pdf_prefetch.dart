import 'package:dio/dio.dart';

/// First-chunk size aimed at linearized PDF page-1 + hint tables (~256 KiB).
const int kPdfPrefetchFirstBytes = 256 * 1024;

/// Issue a single Range GET so the browser/proxy/MinIO has page-1 bytes hot.
Future<void> warmPdfFirstByteRange(
  Uri uri, {
  Map<String, String>? headers,
  int byteCount = kPdfPrefetchFirstBytes,
}) async {
  if (byteCount <= 0) return;
  final end = byteCount - 1;
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      // Absolute URL (proxy or MinIO); do not resolve against the API base.
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  try {
    await client.getUri(
      uri,
      options: Options(
        headers: <String, String>{
          ...?headers,
          'Range': 'bytes=0-$end',
        },
        responseType: ResponseType.bytes,
      ),
    );
  } catch (_) {
    // Best-effort warmup; reader open still works without it.
  } finally {
    client.close(force: true);
  }
}
