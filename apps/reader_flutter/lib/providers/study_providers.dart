import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_models.dart';
import 'api_client.dart';

final studyBookmarksProvider =
    FutureProvider.autoDispose.family<List<StudyBookmark>, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>('/study/bookmarks');
      final raw = res.data?['items'] as List<dynamic>? ?? const [];
      return raw
          .map((e) => StudyBookmark.fromJson(e as Map<String, dynamic>))
          .where((e) => e.bookId == bookId)
          .toList();
    });

final studyNotesProvider =
    FutureProvider.autoDispose.family<List<StudyNote>, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>('/study/notes');
      final raw = res.data?['items'] as List<dynamic>? ?? const [];
      return raw
          .map((e) => StudyNote.fromJson(e as Map<String, dynamic>))
          .where((e) => e.bookId == bookId)
          .toList();
    });

final studyHighlightsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>('/study/highlights');
      final raw = res.data?['items'] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['book'] as String? ?? '') == bookId)
          .toList();
    });

final reminderPreferenceProvider = FutureProvider.autoDispose<ReminderPreference>((ref) async {
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/study/reminder-preference');
    return ReminderPreference.fromJson(res.data ?? const {});
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    // Allow account screen to stay functional when reminder APIs are disabled or backend
    // migrations are not yet applied.
    if (status == 404 || status == 500 || status == 503) {
      return ReminderPreference(
        enabled: false,
        hourUtc: 6,
        minuteUtc: 0,
        weekdaysOnly: false,
      );
    }
    rethrow;
  }
});

final dailyPlansProvider = FutureProvider.autoDispose<List<DailyReadingPlan>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/study/plans');
    final raw = res.data?['items'] as List<dynamic>? ?? const [];
    return raw.map((e) => DailyReadingPlan.fromJson(e as Map<String, dynamic>)).toList();
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status == 404 || status == 500 || status == 503) {
      return const [];
    }
    rethrow;
  }
});

final readingProgressProvider =
    FutureProvider.autoDispose.family<ReadingProgress, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      try {
        final res = await dio.get<Map<String, dynamic>>('/study/progress/$bookId');
        return ReadingProgress.fromJson(res.data ?? const {});
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 500 || status == 503) {
          return ReadingProgress(chapterKey: '', pageNumber: null, progressPercent: 0);
        }
        rethrow;
      }
    });

Future<void> saveReadingProgress(
  WidgetRef ref,
  String bookId, {
  required String chapterKey,
  required int? pageNumber,
  required int progressPercent,
  String? revisionId,
}) async {
  final dio = ref.read(apiDioProvider);
  await dio.put<void>(
    '/study/progress/$bookId',
    data: {
      'chapter_key': chapterKey,
      'page_number': pageNumber,
      'progress_percent': progressPercent.clamp(0, 100),
      if ((revisionId ?? '').isNotEmpty) 'revision': revisionId,
    },
  );
  ref.invalidate(readingProgressProvider(bookId));
}

Future<void> trackReaderEvent(
  WidgetRef ref, {
  required String bookId,
  required String eventName,
  String? chapterKey,
  int? pageNumber,
  String? revisionId,
  Map<String, dynamic>? payload,
}) async {
  final dio = ref.read(apiDioProvider);
  try {
    await dio.post<void>(
      '/study/events',
      data: {
        'book': bookId,
        'event_name': eventName,
        'chapter_key': chapterKey ?? '',
        'page_number': pageNumber,
        if ((revisionId ?? '').isNotEmpty) 'revision': revisionId,
        'payload': payload ?? const {},
      },
    );
  } catch (_) {
    // Fire-and-forget analytics should never break reader UX.
  }
}
