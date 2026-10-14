import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_job.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/download_jobs_storage.dart';
import 'offline_book_download.dart';

const _statusVisibleFor = Duration(seconds: 5);
final Map<String, Timer> _statusDismissTimers = {};

/// Latest download job for [bookId] that should appear on book detail.
///
/// Purchase-required failures are one-shot SnackBars — they are dropped from
/// storage and never returned as a sticky status card. Completed and failed
/// status lines disappear after [_statusVisibleFor].
DownloadJob? visibleDownloadJobForBook(
  WidgetRef ref,
  String bookId,
  List<DownloadJob>? jobs,
) {
  if (jobs == null) return null;
  for (final job in jobs.reversed) {
    if (job.bookId != bookId) continue;
    if (job.state == 'failed' &&
        isPurchaseRequiredDownloadError(job.errorMessage)) {
      unawaited(_forgetPurchaseRequiredFailure(ref, bookId));
      continue;
    }
    if (job.state == 'completed' || job.state == 'failed') {
      _armStatusDismissal(ref, job);
    }
    return job;
  }
  return null;
}

void _armStatusDismissal(WidgetRef ref, DownloadJob job) {
  final key = '${job.bookId}:${job.updatedAtEpochMs}:${job.state}';
  if (_statusDismissTimers.containsKey(key)) return;
  final ageMs = DateTime.now().millisecondsSinceEpoch - job.updatedAtEpochMs;
  final remainingMs = _statusVisibleFor.inMilliseconds - ageMs;
  final container = ProviderScope.containerOf(ref.context);
  _statusDismissTimers[key] = Timer(
    Duration(milliseconds: remainingMs <= 0 ? 0 : remainingMs),
    () => unawaited(_dismissStatus(container, job, key)),
  );
}

Future<void> _dismissStatus(
  ProviderContainer container,
  DownloadJob job,
  String key,
) async {
  _statusDismissTimers.remove(key);
  final jobs = await DownloadJobsStorage.readJobs();
  DownloadJob? current;
  for (final stored in jobs.reversed) {
    if (stored.bookId != job.bookId) continue;
    current = stored;
    break;
  }
  if (current == null) return;
  if (current.updatedAtEpochMs != job.updatedAtEpochMs) return;
  if (current.state != job.state) return;
  await DownloadJobsStorage.removeJob(job.bookId);
  container.invalidate(downloadJobsProvider);
}

Future<void> _forgetPurchaseRequiredFailure(
  WidgetRef ref,
  String bookId,
) async {
  await DownloadJobsStorage.removeJob(bookId);
  ref.invalidate(downloadJobsProvider);
}
