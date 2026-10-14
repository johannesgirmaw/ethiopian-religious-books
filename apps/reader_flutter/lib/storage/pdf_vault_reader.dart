import 'dart:math' as math;
import 'dart:typed_data';

import '../security/book_crypto.dart';

/// Plaintext piece size for an offline PDF. Small enough to seal and open on
/// the UI isolate without holding the whole book in memory.
const int kPdfVaultChunkSize = 256 * 1024;

/// How many opened chunks to keep. Eight pieces is 2 MB of plaintext.
const int kPdfVaultCachedChunks = 8;

/// A failure while sealing a PDF into the vault. [code] is `invalid` when the
/// bytes are not a PDF, or `incomplete` when the download ended early.
class PdfVaultWriteException implements Exception {
  PdfVaultWriteException(this.code);
  final String code;
}

/// A partial generation is safe to delete only when it is not the one the
/// manifest already published. Otherwise a leftover marker would erase the
/// book the reader can still open.
bool pdfVaultPartialIsStale(
  String partialGeneration,
  String? publishedGeneration,
) {
  if (partialGeneration.isEmpty) return false;
  return partialGeneration != publishedGeneration;
}

/// How many sealed pieces a plaintext of [sizeBytes] needs.
int pdfVaultChunkCount(int sizeBytes, {int chunkSize = kPdfVaultChunkSize}) {
  if (sizeBytes <= 0 || chunkSize <= 0) return 0;
  return (sizeBytes + chunkSize - 1) ~/ chunkSize;
}

/// Plaintext length of chunk [index].
int pdfVaultPlainChunkLength(
  int sizeBytes,
  int index, {
  int chunkSize = kPdfVaultChunkSize,
}) {
  final start = index * chunkSize;
  if (start >= sizeBytes) return 0;
  return math.min(chunkSize, sizeBytes - start);
}

/// Reads a sealed offline PDF one range at a time.
///
/// [readSealed] returns one chunk produced by [BookCrypto.seal]. Only a few
/// opened chunks are kept; scrolling back re-opens an older piece.
class ChunkedPdfReader {
  ChunkedPdfReader({
    required this.plainSize,
    required this.revisionId,
    required Future<Uint8List?> Function(int index) readSealed,
    this.chunkSize = kPdfVaultChunkSize,
  }) : _readSealed = readSealed;

  final int plainSize;
  final String revisionId;
  final int chunkSize;
  final Future<Uint8List?> Function(int index) _readSealed;

  final Map<int, Future<Uint8List>> _openings = {};
  final List<int> _recent = [];

  int get chunkCount => pdfVaultChunkCount(plainSize, chunkSize: chunkSize);

  /// Copies plaintext at [position] into [buffer]. Returns how many bytes
  /// were written. pdfrx uses this as the file source.
  Future<int> read(Uint8List buffer, int position, int size) async {
    if (chunkSize <= 0 || size <= 0 || position < 0 || position >= plainSize) {
      return 0;
    }
    final want = math.min(size, math.min(buffer.length, plainSize - position));
    var filled = 0;
    while (filled < want) {
      final pos = position + filled;
      final index = pos ~/ chunkSize;
      final chunk = await _plainChunk(index);
      final start = pos - index * chunkSize;
      if (start >= chunk.length) {
        throw StateError('pdf chunk $index is shorter than expected');
      }
      final n = math.min(chunk.length - start, want - filled);
      buffer.setRange(filled, filled + n, chunk, start);
      filled += n;
    }
    return filled;
  }

  Future<Uint8List> _plainChunk(int index) async {
    final existing = _openings[index];
    if (existing != null) {
      _touch(index);
      try {
        return await existing;
      } catch (_) {
        _drop(index, existing);
        rethrow;
      }
    }
    final opening = _load(index);
    _openings[index] = opening;
    _touch(index);
    _trim();
    try {
      return await opening;
    } catch (_) {
      _drop(index, opening);
      rethrow;
    }
  }

  void _drop(int index, Future<Uint8List> opening) {
    if (!identical(_openings[index], opening)) return;
    _openings.remove(index);
    _recent.remove(index);
  }

  Future<Uint8List> _load(int index) async {
    final sealed = await _readSealed(index);
    if (sealed == null) {
      throw StateError('missing sealed pdf chunk $index');
    }
    final plain = await BookCrypto.open(sealed);
    final expected = pdfVaultPlainChunkLength(
      plainSize,
      index,
      chunkSize: chunkSize,
    );
    if (plain.length != expected) {
      throw StateError('pdf chunk $index has the wrong length');
    }
    return plain;
  }

  void _touch(int index) {
    _recent.remove(index);
    _recent.add(index);
  }

  void _trim() {
    while (_recent.length > kPdfVaultCachedChunks) {
      final dropped = _recent.removeAt(0);
      _openings.remove(dropped);
    }
  }
}
