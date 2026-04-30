import '../utils/rich_text_codec.dart';

class PublishedRevision {
  PublishedRevision({
    required this.id,
    required this.revisionNumber,
    required this.contentFormat,
    this.totalBytes,
  });

  final String id;
  final int revisionNumber;
  final String contentFormat;
  final int? totalBytes;

  factory PublishedRevision.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return PublishedRevision(
        id: '',
        revisionNumber: 0,
        contentFormat: '',
      );
    }
    return PublishedRevision(
      id: j['id'] as String,
      revisionNumber: (j['revision_number'] as num).toInt(),
      contentFormat: j['content_format'] as String? ?? '',
      totalBytes: (j['total_bytes'] as num?)?.toInt(),
    );
  }
}

class BookSummary {
  BookSummary({
    required this.id,
    required this.title,
    this.subtitle,
    this.summary,
    this.summaryRichRaw,
    this.authorCompiler,
    this.primaryLanguage,
    this.catalogVisibility,
    this.publishedRevision,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? summary;
  final String? summaryRichRaw;
  final String? authorCompiler;
  final String? primaryLanguage;
  final String? catalogVisibility;
  final PublishedRevision? publishedRevision;

  factory BookSummary.fromJson(Map<String, dynamic> j) {
    final rawSummary = j['summary'] as String?;
    return BookSummary(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String?,
      summary: plainTextFromStoredSummary(rawSummary),
      summaryRichRaw: rawSummary,
      authorCompiler: j['author_compiler'] as String?,
      primaryLanguage: j['primary_language'] as String?,
      catalogVisibility: j['catalog_visibility'] as String?,
      publishedRevision: j['published_revision'] != null
          ? PublishedRevision.fromJson(
              j['published_revision'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CatalogPage {
  CatalogPage({
    required this.items,
    this.catalogEtag,
  });

  final List<BookSummary> items;
  final String? catalogEtag;

  factory CatalogPage.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] as List<dynamic>? ?? [];
    return CatalogPage(
      items: raw
          .map((e) => BookSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      catalogEtag: j['catalog_etag'] as String?,
    );
  }
}

class BookChapter {
  BookChapter({
    required this.chapterKey,
    required this.title,
    required this.ordinal,
  });

  final String chapterKey;
  final String title;
  final int ordinal;

  factory BookChapter.fromJson(Map<String, dynamic> j) {
    return BookChapter(
      chapterKey: j['chapter_key'] as String? ?? '',
      title: j['title'] as String? ?? '',
      ordinal: (j['ordinal'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookSearchHit {
  BookSearchHit({
    required this.chapterKey,
    required this.pageNumber,
    required this.chunkKey,
    required this.snippet,
  });

  final String chapterKey;
  final int pageNumber;
  final String chunkKey;
  final String snippet;

  factory BookSearchHit.fromJson(Map<String, dynamic> j) {
    return BookSearchHit(
      chapterKey: j['chapter_key'] as String? ?? '',
      pageNumber: (j['page_number'] as num?)?.toInt() ?? 1,
      chunkKey: j['chunk_key'] as String? ?? '',
      snippet: j['snippet'] as String? ?? '',
    );
  }
}

class BookContentPage {
  BookContentPage({
    required this.pageNumber,
    required this.title,
    required this.body,
  });

  final int pageNumber;
  final String title;
  final String body;

  factory BookContentPage.fromJson(Map<String, dynamic> j) {
    return BookContentPage(
      pageNumber: (j['page_number'] as num?)?.toInt() ?? 1,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
    );
  }
}

class BookContentChapter {
  BookContentChapter({
    required this.chapterKey,
    required this.title,
    required this.ordinal,
    required this.pages,
  });

  final String chapterKey;
  final String title;
  final int ordinal;
  final List<BookContentPage> pages;

  factory BookContentChapter.fromJson(Map<String, dynamic> j) {
    final rawPages = j['pages'] as List<dynamic>? ?? const [];
    return BookContentChapter(
      chapterKey: j['chapter_key'] as String? ?? '',
      title: j['title'] as String? ?? '',
      ordinal: (j['ordinal'] as num?)?.toInt() ?? 0,
      pages: rawPages
          .map((e) => BookContentPage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookContentTree {
  BookContentTree({
    required this.chapters,
    required this.totalPages,
  });

  final List<BookContentChapter> chapters;
  final int totalPages;

  factory BookContentTree.fromJson(Map<String, dynamic> j) {
    final raw = j['chapters'] as List<dynamic>? ?? const [];
    return BookContentTree(
      chapters: raw
          .map((e) => BookContentChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPages: (j['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}
