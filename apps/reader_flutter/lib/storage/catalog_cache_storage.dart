import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_models.dart';

class CatalogCacheStorage {
  CatalogCacheStorage._();

  static const String _catalogRawKey = 'catalog_cache_raw';
  static const String _catalogEtagKey = 'catalog_cache_etag';
  static const String _catalogSavedAtKey = 'catalog_cache_saved_at';

  static Future<CatalogPage?> readCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogRawKey);
    if (raw == null || raw.isEmpty) return null;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return CatalogPage.fromJson(parsed);
  }

  static Future<String?> readEtag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_catalogEtagKey);
  }

  static Future<DateTime?> readSavedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_catalogSavedAtKey);
    if (raw == null || raw <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  static Future<void> writeCatalog({
    required Map<String, dynamic> raw,
    required String? etag,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catalogRawKey, jsonEncode(raw));
    if (etag != null && etag.isNotEmpty) {
      await prefs.setString(_catalogEtagKey, etag);
    }
    await prefs.setInt(
      _catalogSavedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
