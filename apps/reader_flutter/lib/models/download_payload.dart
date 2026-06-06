import '../config/dev_object_storage_origin.dart';

class DownloadPayload {
  DownloadPayload({
    required this.bookId,
    required this.revisionId,
    required this.revisionNumber,
    required this.contentFormat,
    required this.manifestUrl,
    required this.packageParts,
    required this.encryption,
  });

  final String bookId;
  final String revisionId;
  final int revisionNumber;
  final String contentFormat;
  final String manifestUrl;
  final List<PackagePart> packageParts;
  final Map<String, dynamic> encryption;

  factory DownloadPayload.fromJson(Map<String, dynamic> j) {
    final rev = j['revision'] as Map<String, dynamic>;
    final parts = (rev['package_parts'] as List<dynamic>? ?? [])
        .map((e) => PackagePart.fromJson(e as Map<String, dynamic>))
        .toList();
    return DownloadPayload(
      bookId: j['book_id'] as String,
      revisionId: rev['id'] as String,
      revisionNumber: (rev['revision_number'] as num).toInt(),
      contentFormat: rev['content_format'] as String? ?? '',
      manifestUrl: rev['manifest_url'] as String,
      packageParts: parts,
      encryption: Map<String, dynamic>.from(rev['encryption'] as Map? ?? {}),
    ).withReachableDevUrls();
  }

  DownloadPayload withReachableDevUrls() {
    return DownloadPayload(
      bookId: bookId,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      contentFormat: contentFormat,
      manifestUrl: rewriteDevObjectStorageUrl(manifestUrl),
      packageParts: packageParts
          .map(
            (part) => PackagePart(
              partIndex: part.partIndex,
              url: rewriteDevObjectStorageUrl(part.url),
              sha256: part.sha256,
              sizeBytes: part.sizeBytes,
            ),
          )
          .toList(),
      encryption: encryption,
    );
  }
}

class PackagePart {
  PackagePart({
    required this.partIndex,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final int partIndex;
  final String url;
  final String sha256;
  final int sizeBytes;

  factory PackagePart.fromJson(Map<String, dynamic> j) {
    return PackagePart(
      partIndex: (j['part_index'] as num).toInt(),
      url: j['url'] as String,
      sha256: j['sha256'] as String? ?? '',
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}
