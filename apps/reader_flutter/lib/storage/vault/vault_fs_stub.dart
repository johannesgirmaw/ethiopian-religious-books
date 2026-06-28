import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Fallback byte storage for the encrypted book vault on platforms without
/// `dart:io` (Flutter web). Sealed (already-encrypted) blobs are base64-encoded
/// into SharedPreferences. Web secure storage is weaker than mobile/desktop
/// hardware keystores; offline encrypted reading is primarily targeted at mobile
/// and desktop, and this keeps web building and functional.

const _prefix = 'vault.v1.';
const _indexKey = 'vault.v1.index';

String _key(String bookId, String name) => '$_prefix$bookId/$name';

Future<void> vaultWrite(String bookId, String name, Uint8List bytes) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_key(bookId, name), base64Encode(bytes));
  final idx = p.getStringList(_indexKey) ?? const [];
  if (!idx.contains(bookId)) {
    await p.setStringList(_indexKey, [...idx, bookId]);
  }
}

Future<Uint8List?> vaultRead(String bookId, String name) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_key(bookId, name));
  if (raw == null) return null;
  return Uint8List.fromList(base64Decode(raw));
}

Future<bool> vaultExists(String bookId, String name) async {
  final p = await SharedPreferences.getInstance();
  return p.containsKey(_key(bookId, name));
}

Future<void> vaultDeleteBook(String bookId) async {
  final p = await SharedPreferences.getInstance();
  final doomed =
      p.getKeys().where((k) => k.startsWith('$_prefix$bookId/')).toList();
  for (final k in doomed) {
    await p.remove(k);
  }
  final idx = p.getStringList(_indexKey) ?? const [];
  await p.setStringList(_indexKey, idx.where((id) => id != bookId).toList());
}

Future<void> vaultClear() async {
  final p = await SharedPreferences.getInstance();
  final doomed = p.getKeys().where((k) => k.startsWith(_prefix)).toList();
  for (final k in doomed) {
    await p.remove(k);
  }
}

Future<List<String>> vaultListBookIds() async {
  final p = await SharedPreferences.getInstance();
  return List<String>.from(p.getStringList(_indexKey) ?? const []);
}
