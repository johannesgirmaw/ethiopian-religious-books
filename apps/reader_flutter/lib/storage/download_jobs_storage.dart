import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_job.dart';

class DownloadJobsStorage {
  DownloadJobsStorage._();

  static const String _key = 'download_jobs_v1';

  static Future<List<DownloadJob>> readJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final parsed = jsonDecode(raw) as List<dynamic>;
    return parsed
        .map((e) => DownloadJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> upsertJob(DownloadJob job) async {
    final jobs = await readJobs();
    final next = jobs.where((e) => e.bookId != job.bookId).toList();
    next.add(job);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
