import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_models.dart';
import 'secure_book_store.dart';

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

/// Offline book cache façade. Historically this wrote **plaintext** book content
/// into SharedPreferences; it now delegates to [SecureBookStore], which seals
/// everything with AES-256-GCM under a device-bound key. The public surface is
/// unchanged so existing callers keep working, but data at rest is encrypted.
///
/// On first use it also wipes any legacy plaintext entries left by older builds.
class BookContentCacheStorage {
  BookContentCacheStorage._();

  static const _legacyPrefix = 'book_content_cache';
  static const _legacyWipedFlag = 'vault_legacy_wiped_v1';
  static bool _migrated = false;

  /// One-time removal of the old unencrypted cache keys. Cheap after first run.
  static Future<void> _ensureMigrated() async {
    if (_migrated) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyWipedFlag) == true) {
      _migrated = true;
      return;
    }
    final doomed =
        prefs.getKeys().where((k) => k.startsWith(_legacyPrefix)).toList();
    for (final key in doomed) {
      await prefs.remove(key);
    }
    await prefs.setBool(_legacyWipedFlag, true);
    _migrated = true;
  }

  static Future<BookContentTree?> readBookContent(String bookId) async {
    await _ensureMigrated();
    return SecureBookStore.readBookContent(bookId);
  }

  static Future<BookCacheMeta?> readBookMeta(String bookId) async {
    await _ensureMigrated();
    return SecureBookStore.readBookMeta(bookId);
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
    await _ensureMigrated();
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedMeta = meta ??
        BookCacheMeta(
          title: titleFromContentTree(BookContentTree.fromJson(raw)) ?? bookId,
          savedAtEpochMs: now,
        );
    await SecureBookStore.writeBookContent(bookId, raw, meta: resolvedMeta);
  }

  static Future<void> writeBookMeta(String bookId, BookCacheMeta meta) async {
    await _ensureMigrated();
    await SecureBookStore.writeBookMeta(bookId, meta);
  }

  static Future<bool> hasBookContent(String bookId) async {
    await _ensureMigrated();
    return SecureBookStore.hasBookContent(bookId);
  }

  static Future<List<String>> listCachedBookIds() async {
    await _ensureMigrated();
    return SecureBookStore.listCachedBookIds();
  }

  static Future<int> cachedBookCount() async {
    await _ensureMigrated();
    return SecureBookStore.cachedBookCount();
  }

  static Future<void> removeBookContent(String bookId) async {
    await _ensureMigrated();
    await SecureBookStore.removeBookContent(bookId);
  }

  static Future<void> clearAll() async {
    await _ensureMigrated();
    await SecureBookStore.clearAll();
  }
}
