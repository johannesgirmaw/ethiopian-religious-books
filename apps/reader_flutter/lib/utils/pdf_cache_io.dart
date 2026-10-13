import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'pdf_book_loader.dart';

File _cacheFileFor(Directory dir, PdfBookAccess access) {
  final safeName = access.filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  return File(
    '${dir.path}/pdf_${access.bookId}_${access.revisionId}_$safeName',
  );
}

/// Returns a finished local copy of [access], or null when the reader should
/// stream the PDF by byte range instead of waiting for the whole file.
Future<String?> cachedPdfPath(PdfBookAccess access) async {
  final dir = await getTemporaryDirectory();
  final file = _cacheFileFor(dir, access);
  if (!await file.exists()) return null;
  final length = await file.length();
  if (!_isAcceptableCacheLength(length, access.sizeBytes)) {
    try {
      await file.delete();
    } catch (_) {}
    return null;
  }
  return file.path;
}

bool _isAcceptableCacheLength(int length, int expectedBytes) {
  if (length <= 8) return false;
  // Prefer exact match against API size; allow unknown expected size.
  if (expectedBytes <= 0) return true;
  return length == expectedBytes;
}

/// Download [uri] into the native temp-dir cache so the next open uses
/// [PdfViewer.file] instead of re-streaming from the network.
///
/// Safe to call after the viewer is already open from [uri]; failures are
/// swallowed so caching never blocks reading. Concurrent calls for the same
/// revision coalesce on the `.part` file path.
Future<void> cachePdfFromNetwork(
  PdfBookAccess access,
  Uri uri, {
  Map<String, String>? headers,
}) async {
  if (access.bookId.isEmpty) return;
  final existing = await cachedPdfPath(access);
  if (existing != null) return;

  final dir = await getTemporaryDirectory();
  final target = _cacheFileFor(dir, access);
  final partial = File('${target.path}.part');
  final lock = File('${target.path}.locking');

  // Cheap single-process lock so two ready-callbacks don't race.
  if (await lock.exists()) {
    final age = DateTime.now().difference(await lock.lastModified());
    if (age < const Duration(minutes: 6)) return;
    try {
      await lock.delete();
    } catch (_) {}
  }
  try {
    await lock.writeAsString('${DateTime.now().millisecondsSinceEpoch}');
  } catch (_) {
    return;
  }

  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );
  try {
    if (await partial.exists()) {
      try {
        await partial.delete();
      } catch (_) {}
    }
    final response = await client.downloadUri(
      uri,
      partial.path,
      options: Options(headers: headers),
    );
    final length = await partial.length();
    final headerLen = int.tryParse(
          response.headers.value('content-length') ?? '',
        ) ??
        0;

    final matchesApi = _isAcceptableCacheLength(length, access.sizeBytes);
    final matchesHeader = headerLen > 0 && length == headerLen;
    final looksLikePdf = await _looksLikePdfFile(partial);
    // Prefer exact API size; if size drifted after linearize, accept a complete
    // Content-Length match that still looks like a PDF.
    final acceptable = matchesApi ||
        (looksLikePdf && (matchesHeader || access.sizeBytes <= 0));
    if (!acceptable) {
      try {
        await partial.delete();
      } catch (_) {}
      return;
    }

    if (await target.exists()) {
      try {
        await target.delete();
      } catch (_) {}
    }
    await partial.rename(target.path);
  } catch (_) {
    try {
      if (await partial.exists()) await partial.delete();
    } catch (_) {}
  } finally {
    client.close(force: true);
    try {
      if (await lock.exists()) await lock.delete();
    } catch (_) {}
  }
}

Future<bool> _looksLikePdfFile(File file) async {
  try {
    final raf = await file.open();
    try {
      final head = await raf.read(5);
      return head.length >= 5 &&
          head[0] == 0x25 &&
          head[1] == 0x50 &&
          head[2] == 0x44 &&
          head[3] == 0x46 &&
          head[4] == 0x2d;
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}
