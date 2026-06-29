import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Native (mobile/desktop) byte storage for the encrypted book vault. Blobs are
/// already AES-256-GCM sealed by [BookCrypto] before they reach here, so the
/// files on disk are ciphertext. Layout: `{appDocuments}/library/{bookId}/{name}`.

Future<Directory> _libraryDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/library');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<Directory> _bookDir(String bookId) async {
  final lib = await _libraryDir();
  final dir = Directory('${lib.path}/$bookId');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<void> vaultWrite(String bookId, String name, Uint8List bytes) async {
  final dir = await _bookDir(bookId);
  // Write-then-rename so a crash mid-write never leaves a half file.
  final tmp = File('${dir.path}/$name.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename('${dir.path}/$name');
}

Future<Uint8List?> vaultRead(String bookId, String name) async {
  final lib = await _libraryDir();
  final f = File('${lib.path}/$bookId/$name');
  if (!await f.exists()) return null;
  return Uint8List.fromList(await f.readAsBytes());
}

Future<bool> vaultExists(String bookId, String name) async {
  final lib = await _libraryDir();
  return File('${lib.path}/$bookId/$name').exists();
}

Future<void> vaultDeleteBook(String bookId) async {
  final lib = await _libraryDir();
  final dir = Directory('${lib.path}/$bookId');
  if (await dir.exists()) await dir.delete(recursive: true);
}

Future<void> vaultClear() async {
  final lib = await _libraryDir();
  if (await lib.exists()) await lib.delete(recursive: true);
}

Future<List<String>> vaultListBookIds() async {
  final lib = await _libraryDir();
  if (!await lib.exists()) return const [];
  final ids = <String>[];
  await for (final entity in lib.list()) {
    if (entity is Directory) {
      final segs = entity.uri.pathSegments.where((s) => s.isNotEmpty);
      if (segs.isNotEmpty) ids.add(segs.last);
    }
  }
  return ids;
}
