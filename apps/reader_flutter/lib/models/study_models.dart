class StudyBookmark {
  StudyBookmark({
    required this.id,
    required this.bookId,
    this.chapterKey,
    this.pageNumber,
    this.label,
    this.snippet,
  });

  final String id;
  final String bookId;
  final String? chapterKey;
  final int? pageNumber;
  final String? label;
  final String? snippet;

  factory StudyBookmark.fromJson(Map<String, dynamic> j) {
    return StudyBookmark(
      id: j['id'] as String? ?? '',
      bookId: j['book'] as String? ?? '',
      chapterKey: j['chapter_key'] as String?,
      pageNumber: (j['page_number'] as num?)?.toInt(),
      label: j['label'] as String?,
      snippet: j['snippet'] as String?,
    );
  }
}

class StudyNote {
  StudyNote({
    required this.id,
    required this.bookId,
    required this.body,
    this.chapterKey,
    this.pageNumber,
  });

  final String id;
  final String bookId;
  final String body;
  final String? chapterKey;
  final int? pageNumber;

  factory StudyNote.fromJson(Map<String, dynamic> j) {
    return StudyNote(
      id: j['id'] as String? ?? '',
      bookId: j['book'] as String? ?? '',
      body: j['body'] as String? ?? '',
      chapterKey: j['chapter_key'] as String?,
      pageNumber: (j['page_number'] as num?)?.toInt(),
    );
  }
}

class ReminderPreference {
  ReminderPreference({
    required this.enabled,
    required this.hourUtc,
    required this.minuteUtc,
    required this.weekdaysOnly,
  });

  final bool enabled;
  final int hourUtc;
  final int minuteUtc;
  final bool weekdaysOnly;

  factory ReminderPreference.fromJson(Map<String, dynamic> j) {
    return ReminderPreference(
      enabled: j['enabled'] as bool? ?? false,
      hourUtc: (j['hour_utc'] as num?)?.toInt() ?? 6,
      minuteUtc: (j['minute_utc'] as num?)?.toInt() ?? 0,
      weekdaysOnly: j['weekdays_only'] as bool? ?? false,
    );
  }
}

class DailyReadingPlan {
  DailyReadingPlan({
    required this.id,
    required this.title,
    required this.isActive,
    required this.items,
  });

  final String id;
  final String title;
  final bool isActive;
  final List<DailyReadingPlanItem> items;

  factory DailyReadingPlan.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List<dynamic>? ?? const [];
    return DailyReadingPlan(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      isActive: j['is_active'] as bool? ?? true,
      items: rawItems
          .map((e) => DailyReadingPlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyReadingPlanItem {
  DailyReadingPlanItem({
    required this.id,
    required this.dayIndex,
    required this.bookId,
    required this.chapterKey,
    this.pageStart,
    this.pageEnd,
    this.note,
  });

  final String id;
  final int dayIndex;
  final String bookId;
  final String chapterKey;
  final int? pageStart;
  final int? pageEnd;
  final String? note;

  factory DailyReadingPlanItem.fromJson(Map<String, dynamic> j) {
    return DailyReadingPlanItem(
      id: j['id'] as String? ?? '',
      dayIndex: (j['day_index'] as num?)?.toInt() ?? 1,
      bookId: j['book'] as String? ?? '',
      chapterKey: j['chapter_key'] as String? ?? '',
      pageStart: (j['page_start'] as num?)?.toInt(),
      pageEnd: (j['page_end'] as num?)?.toInt(),
      note: j['note'] as String?,
    );
  }
}

class ReadingProgress {
  ReadingProgress({
    required this.chapterKey,
    required this.pageNumber,
    required this.progressPercent,
  });

  final String chapterKey;
  final int? pageNumber;
  final int progressPercent;

  factory ReadingProgress.fromJson(Map<String, dynamic> j) {
    return ReadingProgress(
      chapterKey: j['chapter_key'] as String? ?? '',
      pageNumber: (j['page_number'] as num?)?.toInt(),
      progressPercent: (j['progress_percent'] as num?)?.toInt() ?? 0,
    );
  }
}
