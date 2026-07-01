// Models for the verse-addressable Bible API (open content; see /bible/* on the
// Django side). Plain classes with fromJson, matching lib/models/book_models.dart.

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// One canonical book (Genesis, Matthew, …) — its own catalogue entry server-side.
class BibleBook {
  const BibleBook({
    required this.id,
    required this.title,
    required this.nameEn,
    required this.shortNameAm,
    required this.shortNameEn,
    required this.testament,
    required this.canonicalNumber,
    required this.chapterCount,
  });

  final String id;
  final String title; // primary (Amharic) name
  final String nameEn;
  final String shortNameAm;
  final String shortNameEn;
  final String testament; // "old" | "new" | ""
  final int canonicalNumber;
  final int chapterCount;

  bool get isOldTestament => testament == 'old';
  bool get isNewTestament => testament == 'new';

  factory BibleBook.fromJson(Map<String, dynamic> j) => BibleBook(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        nameEn: j['name_en'] as String? ?? '',
        shortNameAm: j['short_name_am'] as String? ?? '',
        shortNameEn: j['short_name_en'] as String? ?? '',
        testament: j['testament'] as String? ?? '',
        canonicalNumber: _toInt(j['canonical_number']),
        chapterCount: _toInt(j['chapter_count']),
      );
}

/// A chapter row in a book's chapter index.
class BibleChapterInfo {
  const BibleChapterInfo({
    required this.chapter,
    required this.verseCount,
    required this.sectionCount,
  });

  final int chapter;
  final int verseCount;
  final int sectionCount;

  factory BibleChapterInfo.fromJson(Map<String, dynamic> j) => BibleChapterInfo(
        chapter: _toInt(j['chapter']),
        verseCount: _toInt(j['verse_count']),
        sectionCount: _toInt(j['section_count']),
      );
}

/// A book plus its chapter index (the chapter picker payload).
class BibleBookIndex {
  const BibleBookIndex({required this.book, required this.chapters});

  final BibleBook book;
  final List<BibleChapterInfo> chapters;

  factory BibleBookIndex.fromJson(Map<String, dynamic> j) => BibleBookIndex(
        book: BibleBook.fromJson(
            (j['book'] as Map?)?.cast<String, dynamic>() ?? const {}),
        chapters: ((j['chapters'] as List?) ?? const [])
            .map((e) => BibleChapterInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// A titled pericope (verse range) within a chapter.
class BibleSection {
  const BibleSection({
    required this.ordinal,
    required this.title,
    required this.startVerse,
    required this.endVerse,
  });

  final int ordinal;
  final String title;
  final int startVerse;
  final int endVerse;

  factory BibleSection.fromJson(Map<String, dynamic> j) => BibleSection(
        ordinal: _toInt(j['ordinal']),
        title: j['title'] as String? ?? '',
        startVerse: _toInt(j['start_verse']),
        endVerse: _toInt(j['end_verse']),
      );
}

/// One verse. [verse] is the displayed/reference number (may be sparse);
/// [sectionOrdinal] links it to its [BibleSection].
class BibleVerse {
  const BibleVerse({
    required this.verse,
    required this.verseSeq,
    required this.text,
    required this.sectionOrdinal,
  });

  final int verse;
  final int verseSeq;
  final String text;
  final int? sectionOrdinal;

  factory BibleVerse.fromJson(Map<String, dynamic> j) => BibleVerse(
        verse: _toInt(j['verse']),
        verseSeq: _toInt(j['verse_seq']),
        text: j['text'] as String? ?? '',
        sectionOrdinal:
            j['section_ordinal'] == null ? null : _toInt(j['section_ordinal']),
      );
}

/// A full chapter: its sections (headings) and ordered verses.
class BibleChapter {
  const BibleChapter({
    required this.book,
    required this.chapter,
    required this.sections,
    required this.verses,
  });

  final BibleBook book;
  final int chapter;
  final List<BibleSection> sections;
  final List<BibleVerse> verses;

  /// Section heading to render *before* the verse with this seq, if any.
  String? headingForSeq(int sectionOrdinal) {
    for (final s in sections) {
      if (s.ordinal == sectionOrdinal) return s.title.isEmpty ? null : s.title;
    }
    return null;
  }

  factory BibleChapter.fromJson(Map<String, dynamic> j) => BibleChapter(
        book: BibleBook.fromJson(
            (j['book'] as Map?)?.cast<String, dynamic>() ?? const {}),
        chapter: _toInt(j['chapter']),
        sections: ((j['sections'] as List?) ?? const [])
            .map((e) => BibleSection.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        verses: ((j['verses'] as List?) ?? const [])
            .map((e) => BibleVerse.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// One verse hit from full-text search.
class BibleSearchHit {
  const BibleSearchHit({
    required this.bookId,
    required this.bookTitle,
    required this.canonicalNumber,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String bookId;
  final String bookTitle;
  final int canonicalNumber;
  final int chapter;
  final int verse;
  final String text;

  factory BibleSearchHit.fromJson(Map<String, dynamic> j) => BibleSearchHit(
        bookId: j['book_id'] as String? ?? '',
        bookTitle: j['book_title'] as String? ?? '',
        canonicalNumber: _toInt(j['canonical_number']),
        chapter: _toInt(j['chapter']),
        verse: _toInt(j['verse']),
        text: j['text'] as String? ?? '',
      );
}

class BibleSearchResult {
  const BibleSearchResult({required this.items, required this.total});

  final List<BibleSearchHit> items;
  final int total;

  factory BibleSearchResult.fromJson(Map<String, dynamic> j) => BibleSearchResult(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => BibleSearchHit.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        total: _toInt(j['total']),
      );
}

class BibleReference {
  const BibleReference({
    required this.book,
    required this.chapter,
    required this.verses,
  });

  final BibleBook book;
  final int chapter;
  final List<BibleVerse> verses;

  int? get firstVerse => verses.isEmpty ? null : verses.first.verse;

  factory BibleReference.fromJson(Map<String, dynamic> j) => BibleReference(
        book: BibleBook.fromJson(
            (j['book'] as Map?)?.cast<String, dynamic>() ?? const {}),
        chapter: _toInt(j['chapter']),
        verses: ((j['verses'] as List?) ?? const [])
            .map((e) => BibleVerse.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
