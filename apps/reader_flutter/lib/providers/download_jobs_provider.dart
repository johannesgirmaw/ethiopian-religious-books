import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_job.dart';
import '../storage/download_jobs_storage.dart';

final downloadJobsProvider = FutureProvider.autoDispose<List<DownloadJob>>((
  ref,
) async {
  return DownloadJobsStorage.readJobs();
});
