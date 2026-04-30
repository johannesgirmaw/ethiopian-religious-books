import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_models.dart';

class BookContentCacheStorage {
  BookContentCacheStorage._();

  static String _contentKey(String bookId) => 'book_content_cache_$bookId';
  static String _savedAtKey(String bookId) => 'book_content_cache_saved_at_$bookId';
  static const String _indexKey = 'book_content_cache_index';

  static Future<BookContentTree?> readBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentKey(bookId));
    if (raw == null || raw.isEmpty) return null;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return BookContentTree.fromJson(parsed);
  }

  static Future<void> writeBookContent(String bookId, Map<String, dynamic> raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentKey(bookId), jsonEncode(raw));
    await prefs.setInt(_savedAtKey(bookId), DateTime.now().millisecondsSinceEpoch);
    final index = prefs.getStringList(_indexKey) ?? const [];
    if (!index.contains(bookId)) {
      await prefs.setStringList(_indexKey, [...index, bookId]);
    }
  }

  static Future<bool> hasBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_contentKey(bookId));
  }

  static Future<int> cachedBookCount() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? const [];
    return index.length;
  }

  static Future<void> removeBookContent(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contentKey(bookId));
    await prefs.remove(_savedAtKey(bookId));
    final index = prefs.getStringList(_indexKey) ?? const [];
    await prefs.setStringList(_indexKey, index.where((id) => id != bookId).toList());
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? const [];
    for (final bookId in index) {
      await prefs.remove(_contentKey(bookId));
      await prefs.remove(_savedAtKey(bookId));
    }
    await prefs.setStringList(_indexKey, const []);
  }
}
