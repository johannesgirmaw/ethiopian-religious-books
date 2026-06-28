import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/download_job.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../security/device_identity.dart';
import '../storage/download_jobs_storage.dart';
import '../storage/secure_book_store.dart';
import 'dio_connection_message.dart';

/// A download failure with a ready-to-show, user-facing [message].
class _DownloadException implements Exception {
  _DownloadException(this.message);
  final String message;
}

/// Parse the server's ISO-8601 license expiry into epoch millis, defaulting to a
/// conservative 30-day lease if the field is missing or unparseable.
int _expiryEpochMs(String? iso) {
  if (iso != null && iso.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(iso);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
}

/// Downloads a book for **encrypted** offline reading. Returns a user-facing
/// error, or null on success.
///
/// Flow: register this device → obtain a server-issued offline license (the
/// backend re-checks entitlement here, so unowned books are rejected) → fetch
/// the content, which [bookContentProvider] seals into the device-bound vault →
/// store the license. The content is therefore never written to disk in
/// plaintext, and the book only opens offline while the lease is valid.
Future<String?> runOfflineBookDownload(
  WidgetRef ref,
  String bookId, {
  AppLocalizations? l10n,
}) async {
  await DownloadJobsStorage.upsertJob(
    DownloadJob(
      bookId: bookId,
      state: 'in_progress',
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  try {
    final dio = ref.read(apiDioProvider);
    await DeviceIdentity.ensureRegistered(dio);
    final deviceId = await DeviceIdentity.deviceId();

    // 1) Obtain the offline license (entitlement-checked server-side).
    final licRes = await dio.post<Map<String, dynamic>>(
      'books/$bookId/license',
      data: {'device_id': deviceId},
    );
    final licBody = licRes.data ?? const <String, dynamic>{};
    final lic = (licBody['license'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final token = (lic['token'] as String?)?.trim() ?? '';
    if (token.isEmpty) {
      throw _DownloadException('Could not obtain an offline license.');
    }

    // 2) Fetch content — this seals it into the encrypted vault as a side effect.
    final tree = await ref.read(bookContentProvider(bookId).future);
    if (tree.chapters.isEmpty) {
      throw _DownloadException('This book has no readable content yet.');
    }

    // 3) Persist the license so the book can be opened offline.
    await SecureBookStore.writeLicense(
      bookId,
      OfflineLicense(
        token: token,
        deviceId: deviceId,
        expiresAtEpochMs: _expiryEpochMs(lic['expires_at'] as String?),
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
    return null;
  } catch (e) {
    final message = e is _DownloadException
        ? e.message
        : friendlyDownloadError(e, l10n: l10n);
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

String friendlyDownloadError(
  Object error, {
  AppLocalizations? l10n,
}) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) {
      return 'You need to purchase this book before you can download it.';
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
