import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_models.dart';

/// Title/author stored when saving offline content (survives catalog changes).
class BookCacheMeta {
  BookCacheMeta({
    required this.title,
    this.authorCompiler,
    this.primaryLanguage,
    this.savedAtEpochMs,
  });

  final String title;
  final String? authorCompiler;
  final String? primaryLanguage;
  final int? savedAtEpochMs;

  Map<String, dynamic> toJson() => {
        'title': title,
        if (authorCompiler != null) 'author_compiler': authorCompiler,
        if (primaryLanguage != null) 'primary_language': primaryLanguage,
        if (savedAtEpochMs != null) 'saved_at': savedAtEpochMs,
      };

  factory BookCacheMeta.fromJson(Map<String, dynamic> j) {
    return BookCacheMeta(
      title: (j['title'] as String?)?.trim().isNotEmpty == true
          ? j['title'] as String
          : '',
      authorCompiler: j['author_compiler'] as String?,
      primaryLanguage: j['primary_language'] as String?,
      savedAtEpochMs: (j['saved_at'] as num?)?.toInt(),
    );
  }
}

class BookContentCacheStorage {
  BookContentCacheStorage._();

  static String _contentKey(String bookId) => 'book_content_cache_$bookId';
  static String _metaKey(String bookId) => 'book_content_cache_meta_$bookId';
  static String _savedAtKey(String bookId) => 'book_content_cache_saved_at_$bookId';
  static const String _indexKey = 'book_content_cache_index';

  static Future<BookContentTree?> readBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentKey(bookId));
    if (raw == null || raw.isEmpty) return null;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return BookContentTree.fromJson(parsed);
  }

  static Future<BookCacheMeta?> readBookMeta(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey(bookId));
    if (raw == null || raw.isEmpty) return null;
    final meta = BookCacheMeta.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (meta.title.isEmpty) return null;
    return meta;
  }

  static String? titleFromContentTree(BookContentTree? tree) {
    if (tree == null || tree.chapters.isEmpty) return null;
    final first = tree.chapters.first.title.trim();
    if (first.isNotEmpty) return first;
    return null;
  }

  static Future<void> writeBookContent(
    String bookId,
    Map<String, dynamic> raw, {
    BookCacheMeta? meta,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_contentKey(bookId), jsonEncode(raw));
    await prefs.setInt(_savedAtKey(bookId), now);

    final resolvedMeta = meta ??
        BookCacheMeta(
          title: titleFromContentTree(BookContentTree.fromJson(raw)) ?? bookId,
          savedAtEpochMs: now,
        );
    if (resolvedMeta.title.isNotEmpty) {
      await prefs.setString(
        _metaKey(bookId),
        jsonEncode(resolvedMeta.toJson()),
      );
    }

    final index = prefs.getStringList(_indexKey) ?? const [];
    if (!index.contains(bookId)) {
      await prefs.setStringList(_indexKey, [...index, bookId]);
    }
  }

  static Future<void> writeBookMeta(String bookId, BookCacheMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    if (meta.title.trim().isEmpty) return;
    await prefs.setString(_metaKey(bookId), jsonEncode(meta.toJson()));
  }

  static Future<bool> hasBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_contentKey(bookId));
  }

  static Future<List<String>> listCachedBookIds() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_indexKey) ?? const []);
  }

  static Future<int> cachedBookCount() async {
    final ids = await listCachedBookIds();
    return ids.length;
  }

  static Future<void> removeBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contentKey(bookId));
    await prefs.remove(_metaKey(bookId));
    await prefs.remove(_savedAtKey(bookId));
    final index = prefs.getStringList(_indexKey) ?? const [];
    await prefs.setStringList(_indexKey, index.where((id) => id != bookId).toList());
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? const [];
    for (final bookId in index) {
      await prefs.remove(_contentKey(bookId));
      await prefs.remove(_metaKey(bookId));
      await prefs.remove(_savedAtKey(bookId));
    }
    await prefs.setStringList(_indexKey, const []);
  }
}
