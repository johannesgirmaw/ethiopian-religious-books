import 'dart:typed_data';

import 'vault/vault_fs_io.dart';

String _dirName(String generation) => 'pdf_$generation';

String _chunkName(String generation, int index) =>
    '${_dirName(generation)}/$index.enc';

/// One sealed PDF chunk. The bytes are already AES-256-GCM ciphertext.
Future<void> writeSealedChunk(
  String bookId,
  String generation,
  int index,
  Uint8List sealed,
) => vaultWrite(bookId, _chunkName(generation, index), sealed);

Future<Uint8List?> readSealedChunk(
  String bookId,
  String generation,
  int index,
) => vaultRead(bookId, _chunkName(generation, index));

Future<bool> hasSealedChunk(String bookId, String generation, int index) =>
    vaultExists(bookId, _chunkName(generation, index));

/// [chunkCount] is unused: the generation is one directory.
Future<void> deleteSealedGeneration(
  String bookId,
  String generation,
  int chunkCount,
) async {
  if (chunkCount < 0) return;
  await vaultDeleteRelative(bookId, _dirName(generation));
}

/// Chunk files live under the book directory and go away with [vaultClear].
Future<void> clearPdfBlobs() async {}
