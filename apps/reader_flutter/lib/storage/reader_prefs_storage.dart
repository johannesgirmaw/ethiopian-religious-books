import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReaderBookmark {
  ReaderBookmark({
    required this.progress,
    required this.label,
    this.snippet,
    required this.savedAtEpochMs,
  });

  final double progress;
  final String label;
  final String? snippet;
  final int savedAtEpochMs;

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'label': label,
        'snippet': snippet,
        'saved_at': savedAtEpochMs,
      };

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? 'Bookmark',
      snippet: json['snippet'] as String?,
      savedAtEpochMs: (json['saved_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class LastOpenedBook {
  LastOpenedBook({
    required this.bookId,
    required this.title,
    required this.updatedAtEpochMs,
  });

  final String bookId;
  final String title;
  final int updatedAtEpochMs;

  Map<String, dynamic> toJson() => {
        'book_id': bookId,
        'title': title,
        'updated_at': updatedAtEpochMs,
      };

  factory LastOpenedBook.fromJson(Map<String, dynamic> json) {
    return LastOpenedBook(
      bookId: json['book_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      updatedAtEpochMs: (json['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReaderPrefsStorage {
  ReaderPrefsStorage._();

  static const _lastOpenedKey = 'reader_last_opened_book';

  static String _progressKey(String bookId) => 'reader_progress_$bookId';
  static String _fontSizeKey(String bookId) => 'reader_font_size_$bookId';
  static String _themeKey(String bookId) => 'reader_theme_$bookId';
  static String _pageCurlKey(String bookId) => 'reader_page_curl_$bookId';
  static String _bookmarksKey(String bookId) => 'reader_bookmarks_$bookId';

  static Future<double> readProgress(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_progressKey(bookId)) ?? 0;
  }

  static Future<void> writeProgress(String bookId, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_progressKey(bookId), progress.clamp(0, 1));
  }

  static Future<double> readFontSize(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey(bookId)) ?? 18;
  }

  static Future<void> writeFontSize(String bookId, double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey(bookId), fontSize.clamp(15, 28));
  }

  static Future<String> readThemeMode(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey(bookId)) ?? 'light';
  }

  static Future<void> writeThemeMode(String bookId, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey(bookId), mode);
  }

  static Future<bool> readPageCurlMode(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pageCurlKey(bookId)) ?? true;
  }

  static Future<void> writePageCurlMode(String bookId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pageCurlKey(bookId), enabled);
  }

  static Future<List<ReaderBookmark>> readBookmarks(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarksKey(bookId));
    if (raw == null || raw.isEmpty) return const [];
    final parsed = jsonDecode(raw) as List<dynamic>;
    return parsed
        .map((e) => ReaderBookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> writeBookmarks(
    String bookId,
    List<ReaderBookmark> bookmarks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(bookmarks.map((e) => e.toJson()).toList());
    await prefs.setString(_bookmarksKey(bookId), raw);
  }

  static Future<LastOpenedBook?> readLastOpenedBook() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastOpenedKey);
    if (raw == null || raw.isEmpty) return null;
    return LastOpenedBook.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static Future<void> writeLastOpenedBook(LastOpenedBook book) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, jsonEncode(book.toJson()));
  }
}
