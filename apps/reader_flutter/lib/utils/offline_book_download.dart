import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/download_job.dart';
import '../providers/catalog_providers.dart';
import '../storage/download_jobs_storage.dart';
import 'dio_connection_message.dart';

/// Downloads a book revision for offline reading. Returns a user-facing error, or null on success.
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
    final payload = await ref.read(downloadInfoProvider(bookId).future);
    final dir = await getApplicationDocumentsDirectory();
    final bookDir =
        Directory('${dir.path}/books/$bookId/${payload.revisionId}');
    await bookDir.create(recursive: true);
    final manifestPath = '${bookDir.path}/manifest.json';
    final plain = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    await plain.download(payload.manifestUrl, manifestPath);
    for (final part in payload.packageParts) {
      final name = 'part_${part.partIndex}.bin';
      await plain.download(part.url, '${bookDir.path}/$name');
    }
    await DownloadJobsStorage.upsertJob(
      DownloadJob(
        bookId: bookId,
        state: 'completed',
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return null;
  } catch (e) {
    final message = friendlyDownloadError(e, l10n: l10n);
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
