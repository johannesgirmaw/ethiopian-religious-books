import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_job.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/download_jobs_storage.dart';
import 'offline_book_download.dart';

/// Latest download job for [bookId] that should appear on book detail.
///
/// Purchase-required failures are one-shot SnackBars — they are dropped from
/// storage and never returned as a sticky status card.
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
    return job;
  }
  return null;
}

Future<void> _forgetPurchaseRequiredFailure(
  WidgetRef ref,
  String bookId,
) async {
  await DownloadJobsStorage.removeJob(bookId);
  ref.invalidate(downloadJobsProvider);
}
