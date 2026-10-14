import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../models/download_job.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../security/device_identity.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/download_jobs_storage.dart';
import '../storage/pdf_vault_reader.dart';
import '../storage/secure_book_store.dart';
import 'dio_connection_message.dart';
import 'pdf_book_loader.dart';

/// A download failure with a ready-to-show, user-facing [message].
class _DownloadException implements Exception {
  _DownloadException(this.message, {this.kind = 'generic'});
  final String message;
  final String kind;
}

/// Parse the server's ISO-8601 license expiry into epoch millis.
///
/// Returns null when missing or unparseable — callers must fail closed rather
/// than inventing a lease window the server did not grant.
int? _expiryEpochMs(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  return DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}

/// Downloads a book for **encrypted** offline reading. Returns a user-facing
/// error, or null on success.
///
/// Flow: register this device → obtain a server-issued offline license (the
/// backend re-checks entitlement here, so unowned books are rejected) → fetch
/// the content. Chapter books are sealed by [bookContentProvider]; PDF books
/// are downloaded in full and sealed as ciphertext. Then store the license.
/// Plaintext is never written to disk, and the book only opens offline while
/// the lease is valid.
/// Web offline PDFs are fully decrypted in memory. Warn before saving large ones.
const _webOfflineWarnBytes = 25 * 1024 * 1024;

Future<String?> runOfflineBookDownload(
  WidgetRef ref,
  String bookId, {
  AppLocalizations? l10n,
  BuildContext? context,
}) async {
  await DownloadJobsStorage.upsertJob(
    DownloadJob(
      bookId: bookId,
      state: 'in_progress',
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  ref.invalidate(downloadJobsProvider);
  try {
    final dio = ref.read(apiDioProvider);
    await DeviceIdentity.ensureRegistered(dio);
    final deviceId = await DeviceIdentity.deviceId();

    // 1) Obtain the offline license (entitlement-checked server-side).
    Map<String, dynamic> licBody;
    try {
      final licRes = await dio.post<Map<String, dynamic>>(
        'books/$bookId/license',
        data: {'device_id': deviceId},
      );
      licBody = licRes.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      // Stale in-memory registration after account switch — re-register once.
      final code = (e.response?.data is Map)
          ? ((e.response!.data as Map)['error'] is Map
                ? ((e.response!.data as Map)['error'] as Map)['code']
                : null)
          : null;
      if (e.response?.statusCode == 400 && code == 'DEVICE_NOT_REGISTERED') {
        await DeviceIdentity.ensureRegistered(dio, force: true);
        final retry = await dio.post<Map<String, dynamic>>(
          'books/$bookId/license',
          data: {'device_id': deviceId},
        );
        licBody = retry.data ?? const <String, dynamic>{};
      } else {
        rethrow;
      }
    }
    final lic =
        (licBody['license'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final token = (lic['token'] as String?)?.trim() ?? '';
    if (token.isEmpty || deviceId.isEmpty) {
      throw _DownloadException('Could not obtain an offline license.');
    }
    final expiresMs = _expiryEpochMs(lic['expires_at'] as String?);
    if (expiresMs == null) {
      throw _DownloadException('Could not obtain an offline license.');
    }

    // 2) Seal the book. PDF revisions have no chapter tree; the file itself
    // is the readable content.
    final book = await ref.read(bookDetailProvider(bookId).future);
    if (book.isPdf) {
      if (kIsWeb && context != null && context.mounted) {
        final access = await ref.read(pdfBookAccessProvider(bookId).future);
        final size = access.sizeBytes;
        if (size >= _webOfflineWarnBytes) {
          final dialogContext = context;
          if (!dialogContext.mounted) {
            await DownloadJobsStorage.removeJob(bookId);
            ref.invalidate(downloadJobsProvider);
            return null;
          }
          final ok = await _confirmLargeWebPdf(dialogContext, size, l10n);
          if (ok != true) {
            await DownloadJobsStorage.removeJob(bookId);
            ref.invalidate(downloadJobsProvider);
            return null;
          }
        }
      }
      await _storeOfflinePdf(ref, book, l10n: l10n);
    } else {
      final tree = await ref.read(bookContentProvider(bookId).future);
      if (tree.chapters.isEmpty) {
        throw _DownloadException('This book has no readable content yet.');
      }
    }

    // 3) Persist the license so the book can be opened offline.
    await SecureBookStore.writeLicense(
      bookId,
      OfflineLicense(
        token: token,
        deviceId: deviceId,
        expiresAtEpochMs: expiresMs,
        revisionId: licBody['revision_id'] as String?,
      ),
    );

    await DownloadJobsStorage.upsertJob(
      DownloadJob(
        bookId: bookId,
        state: 'completed',
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    ref.invalidate(offlineBookCachedProvider(bookId));
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineDownloadsListProvider);
    if (book.isPdf) {
      ref.invalidate(pdfViewerSourceProvider(bookId));
      ref.invalidate(pdfBookAccessProvider(bookId));
    }
    return null;
  } catch (e) {
    final message = e is _DownloadException
        ? e.message
        : friendlyDownloadError(e, l10n: l10n);
    // Purchase-required failures are shown once via SnackBar — do not leave a
    // sticky failed job on the book detail page.
    if (isPurchaseRequiredDownloadError(message) ||
        (e is DioException && e.response?.statusCode == 403)) {
      await SecureBookStore.revokeOfflineLicense(bookId);
      await DownloadJobsStorage.removeJob(bookId);
      return l10n?.downloadRequiresPurchase ??
          'You need to purchase this book before you can download it.';
    }
    if (await _savedPdfStillReadable(bookId)) {
      // The new download did not replace the sealed copy.
      await DownloadJobsStorage.removeJob(bookId);
      return l10n?.downloadPdfKeptLocal ??
          'Couldn\'t refresh this PDF. Your saved copy is still on this device.';
    }
    await DownloadJobsStorage.upsertJob(
      DownloadJob(
        bookId: bookId,
        state: 'failed',
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        errorMessage: message,
      ),
    );
    return message;
  }
}

const _pdfDownloadTimeout = Duration(minutes: 10);

Future<bool?> _confirmLargeWebPdf(
  BuildContext context,
  int sizeBytes,
  AppLocalizations? l10n,
) {
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
  final sizeLabel = '$mb MB';
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final loc = l10n ?? AppLocalizations.of(context);
      return AlertDialog(
        content: Text(loc.pdfOfflineLargeWarning(sizeLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.pdfOfflineLargeContinue),
          ),
        ],
      );
    },
  );
}

Future<bool> _savedPdfStillReadable(String bookId) async {
  if (!await SecureBookStore.hasPdf(bookId)) return false;
  final deviceId = await DeviceIdentity.deviceId();
  return SecureBookStore.hasValidOfflineAccess(bookId, deviceId: deviceId);
}

Future<void> _storeOfflinePdf(
  WidgetRef ref,
  BookSummary book, {
  AppLocalizations? l10n,
}) async {
  final access = await ref.read(pdfBookAccessProvider(book.id).future);
  final title = book.title.trim().isEmpty ? book.id : book.title.trim();
  await SecureBookStore.exclusivePdfSave(book.id, () async {
    final opened = await _openPdfByteStream(
      ref.read(apiDioProvider),
      access,
      l10n: l10n,
    );
    try {
      await SecureBookStore.writePdfFromStream(
        book.id,
        opened.stream,
        expectedBytes: opened.expectedBytes,
        revisionId: access.revisionId,
        filename: access.filename,
        meta: BookCacheMeta(
          title: title,
          authorCompiler: book.authorCompiler,
          primaryLanguage: book.primaryLanguage,
          contentFormat: 'pdf',
          savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } on PdfVaultWriteException catch (e) {
      if (e.code == 'invalid') {
        throw _DownloadException(
          l10n?.downloadPdfInvalid ??
              'This file is not a valid PDF and could not be saved for offline reading.',
          kind: 'invalid',
        );
      }
      throw _DownloadException(
        l10n?.downloadErrorGeneric ?? 'Download failed. Please try again.',
      );
    } finally {
      try {
        await opened.close();
      } catch (_) {}
    }
  });
}

class _PdfByteStream {
  _PdfByteStream(this.stream, this.expectedBytes, this.close);
  final Stream<List<int>> stream;
  final int expectedBytes;
  final Future<void> Function() close;
}

Future<_PdfByteStream> _openPdfByteStream(
  Dio api,
  PdfBookAccess access, {
  AppLocalizations? l10n,
}) async {
  if (kIsWeb) {
    final res = await api.get<ResponseBody>(
      'books/${access.bookId}/pdf/bytes',
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: _pdfDownloadTimeout,
      ),
    );
    final body = res.data;
    if (body == null) {
      throw _DownloadException(
        l10n?.downloadErrorGeneric ?? 'Download failed. Please try again.',
      );
    }
    return _PdfByteStream(
      body.stream,
      _expectedPdfBytes(access, res.headers),
      () async {},
    );
  }

  final url = access.url.trim();
  if (url.isEmpty) {
    throw _DownloadException(
      l10n?.downloadErrorGeneric ?? 'Download failed. Please try again.',
    );
  }
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: _pdfDownloadTimeout,
      responseType: ResponseType.stream,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  try {
    final res = await client.getUri<ResponseBody>(Uri.parse(url));
    final body = res.data;
    if (body == null) {
      throw _DownloadException(
        l10n?.downloadErrorGeneric ?? 'Download failed. Please try again.',
      );
    }
    return _PdfByteStream(
      body.stream,
      _expectedPdfBytes(access, res.headers),
      () async {
        client.close(force: true);
      },
    );
  } catch (e) {
    client.close(force: true);
    rethrow;
  }
}

int _expectedPdfBytes(PdfBookAccess access, Headers headers) {
  if (access.sizeBytes > 0) return access.sizeBytes;
  return int.tryParse(headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
}

/// Re-fetch a saved book. PDF copies are downloaded again; chapter books
/// refresh through [bookContentProvider].
Future<String?> syncOfflineBook(
  WidgetRef ref,
  String bookId, {
  AppLocalizations? l10n,
  BuildContext? context,
}) async {
  final hasPdf = await SecureBookStore.hasPdf(bookId);
  var isPdf = hasPdf;
  if (!isPdf) {
    try {
      isPdf = (await ref.read(bookDetailProvider(bookId).future)).isPdf;
    } catch (_) {}
  }
  if (isPdf) {
    return runOfflineBookDownload(
      ref,
      bookId,
      l10n: l10n,
      context: context,
    );
  }
  ref.invalidate(bookContentProvider(bookId));
  await ref.read(bookContentProvider(bookId).future);
  try {
    await ref.read(bookDetailProvider(bookId).future);
  } on DioException {
    // Meta update is best-effort when offline.
  }
  return null;
}

/// True when [message] is the one-shot "must purchase first" download error.
bool isPurchaseRequiredDownloadError(String? message) {
  if (message == null || message.trim().isEmpty) return false;
  final lower = message.toLowerCase();
  // English (en arb) + stable key fragment + Amharic (am arb) leftovers.
  return lower.contains('purchase this book before you can download') ||
      lower.contains('downloadrequirespurchase') ||
      message.contains('ከማውረድዎ በፊት ይህን መጽሐፍ መግዛት');
}

String friendlyDownloadError(Object error, {AppLocalizations? l10n}) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) {
      return l10n?.downloadRequiresPurchase ??
          'You need to purchase this book before you can download it.';
    }
    if (code == 404) {
      return 'This book is not available for download yet.';
    }
    if (_isDevStorageDownloadError(error)) {
      return l10n?.downloadErrorStorageUnreachable ??
          'Could not reach the file server. Make sure Docker is running (MinIO on port 19000) '
              'and this device can reach your development machine on the same network.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return l10n?.downloadErrorTimeout ??
            'Download timed out. Try again when you have a stable connection.';
      case DioExceptionType.connectionError:
        return connectionTroubleshootHint(error) ??
            l10n?.downloadErrorConnection ??
            'Could not connect to download the book. Check your connection and try again.';
      default:
        break;
    }
    final hint = connectionTroubleshootHint(error);
    if (hint != null) {
      return hint;
    }
  }
  return l10n?.downloadErrorGeneric ?? 'Download failed. Please try again.';
}

/// Maps a stored job error (may be legacy raw Dio text) to a short user-facing line.
String displayDownloadJobError(String? raw, AppLocalizations l10n) {
  if (raw == null || raw.trim().isEmpty) {
    return l10n.downloadFailedGeneric;
  }
  final lower = raw.toLowerCase();
  if ((lower.contains('localhost') || lower.contains('127.0.0.1')) &&
      lower.contains('19000')) {
    return l10n.downloadErrorStorageUnreachable;
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return l10n.downloadErrorTimeout;
  }
  if (lower.contains('dioexception') ||
      lower.contains('socketexception') ||
      lower.contains('connection failed') ||
      lower.contains('connection error')) {
    return l10n.downloadErrorConnection;
  }
  if (raw.length > 120) {
    return l10n.downloadErrorGeneric;
  }
  return raw;
}

bool _isDevStorageDownloadError(DioException error) {
  final url = error.requestOptions.uri.toString().toLowerCase();
  if (url.contains(':19000') || url.contains('minio')) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return (text.contains('localhost') || text.contains('127.0.0.1')) &&
      text.contains('19000');
}
