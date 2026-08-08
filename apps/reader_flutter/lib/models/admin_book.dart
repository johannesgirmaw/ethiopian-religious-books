double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class AdminBooksPage {
  AdminBooksPage({required this.items, required this.total});

  final List<AdminBook> items;
  final int total;

  factory AdminBooksPage.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final list = raw is List
        ? raw
            .map((e) => AdminBook.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminBook>[];
    return AdminBooksPage(
      items: list,
      total: (j['total'] as num?)?.toInt() ?? list.length,
    );
  }
}

class AdminBook {
  AdminBook({
    required this.id,
    required this.title,
    this.subtitle,
    this.summary,
    this.authorCompiler,
    required this.primaryLanguage,
    required this.scriptTags,
    this.tagSlugs = const [],
    required this.chaptersDraft,
    required this.catalogVisibility,
    this.reviewStatus = 'draft',
    this.latestReviewNote,
    this.genre,
    this.isBible = false,
    this.testamentType,
    this.publishedYear,
    this.isPremium = false,
    this.isFeatured = false,
    this.authorId,
    this.currency = 'USD',
    this.price = 0,
    this.salePrice,
    this.commissionPercent,
    this.coverObjectKey,
    this.coverGetUrl,
    this.publishedRevisionId,
    this.publishedRevisionNumber,
    this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? summary;
  final String? authorCompiler;
  final String primaryLanguage;
  final List<String> scriptTags;
  final List<String> tagSlugs;
  final List<AdminDraftChapter> chaptersDraft;
  final String catalogVisibility;

  /// Editorial review state: 'draft' | 'in_review' | 'reviewed'. Orthogonal to
  /// [catalogVisibility] — a book is published separately, only once reviewed.
  final String reviewStatus;

  /// Most recent review-round note (e.g. the reviewer's change request), if any.
  final BookReviewNote? latestReviewNote;
  final String? genre;

  /// Bible books hold verse content (managed via the Bible chapter editor),
  /// not page-based [chaptersDraft].
  final bool isBible;

  /// "old" | "new" | null — only meaningful when [isBible].
  final String? testamentType;
  final int? publishedYear;
  final bool isPremium;
  final bool isFeatured;
  final String? authorId;
  final String currency;
  final double price;
  final double? salePrice;
  final double? commissionPercent;
  final String? coverObjectKey;
  final String? coverGetUrl;
  final String? publishedRevisionId;
  final int? publishedRevisionNumber;
  final String? createdById;
  final String? createdAt;
  final String? updatedAt;

  factory AdminBook.fromJson(Map<String, dynamic> j) {
    List<String> tags = [];
    final st = j['script_tags'];
    if (st is List) {
      tags = st.map((e) => e.toString()).toList();
    }
    List<String> tagSlugs = [];
    final ts = j['tag_slugs'];
    if (ts is List) {
      tagSlugs = ts.map((e) => e.toString()).toList();
    }
    List<AdminDraftChapter> chapters = [];
    final cd = j['chapters_draft'];
    if (cd is List) {
      chapters = cd
          .whereType<Map>()
          .map((e) => AdminDraftChapter.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return AdminBook(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String?,
      summary: j['summary'] as String?,
      authorCompiler: j['author_compiler'] as String?,
      primaryLanguage: j['primary_language'] as String? ?? 'am',
      scriptTags: tags,
      tagSlugs: tagSlugs,
      chaptersDraft: chapters,
      catalogVisibility: j['catalog_visibility'] as String? ?? 'hidden',
      reviewStatus: j['review_status'] as String? ?? 'draft',
      latestReviewNote: j['latest_review_note'] is Map
          ? BookReviewNote.fromJson(
              Map<String, dynamic>.from(j['latest_review_note'] as Map))
          : null,
      genre: j['genre'] as String?,
      isBible: j['is_bible'] as bool? ?? false,
      testamentType: j['testament_type'] as String?,
      publishedYear: (j['published_year'] as num?)?.toInt(),
      isPremium: j['is_premium'] as bool? ?? false,
      isFeatured: j['is_featured'] as bool? ?? false,
      authorId: j['author'] as String?,
      currency: (j['currency'] as String?)?.trim().isNotEmpty == true
          ? j['currency'] as String
          : 'USD',
      price: _toDouble(j['price']),
      salePrice: j['sale_price'] == null ? null : _toDouble(j['sale_price']),
      commissionPercent: j['commission_percent'] == null
          ? null
          : _toDouble(j['commission_percent']),
      coverObjectKey: j['cover_object_key'] as String?,
      coverGetUrl: j['cover_get_url'] as String?,
      publishedRevisionId: j['published_revision_id'] as String?,
      publishedRevisionNumber:
          (j['published_revision_number'] as num?)?.toInt(),
      createdById: j['created_by_id'] as String?,
      createdAt: j['created_at'] as String?,
      updatedAt: j['updated_at'] as String?,
    );
  }

  bool get isPublished => catalogVisibility == 'published';

  bool get isDraftReview => reviewStatus == 'draft';
  bool get isInReview => reviewStatus == 'in_review';
  bool get isReviewed => reviewStatus == 'reviewed';

  /// Single status shown to book managers. Published visibility takes
  /// precedence over the editorial [reviewStatus].
  AdminBookDisplayStatus get displayStatus {
    if (isPublished) return AdminBookDisplayStatus.published;
    switch (reviewStatus) {
      case 'in_review':
        return AdminBookDisplayStatus.inReview;
      case 'reviewed':
        return AdminBookDisplayStatus.reviewed;
      default:
        return AdminBookDisplayStatus.draft;
    }
  }

  /// True when this book is still a pure draft and so may be deleted: never
  /// published, not sitting in the editorial review queue. The server applies
  /// the same rule plus ownership and purchase-history checks, so a delete can
  /// still be refused with a 409.
  bool get isDeletableDraft =>
      !isPublished && isDraftReview && publishedRevisionId == null;

  /// True when the author is looking at a draft that was sent back with a
  /// change request they still need to address.
  bool get hasPendingChangeRequest =>
      isDraftReview && (latestReviewNote?.isChangesRequested ?? false);

  bool isCreatedBy(String? userId) =>
      userId != null && createdById != null && createdById == userId;
}

/// The status a book manager sees for a book, merging catalog visibility with
/// the editorial review lifecycle.
enum AdminBookDisplayStatus { draft, inReview, reviewed, published }

/// One entry in a book's editorial review history.
class BookReviewNote {
  BookReviewNote({
    required this.id,
    required this.decision,
    required this.comment,
    required this.commentPlain,
    this.reviewerId,
    this.reviewerEmail,
    this.createdAt,
  });

  final String id;

  /// 'submitted' | 'approved' | 'changes_requested' | 'withdrawn'.
  final String decision;

  /// Rich-text (Quill delta JSON) comment; non-empty for change requests.
  final String comment;
  final String commentPlain;
  final String? reviewerId;
  final String? reviewerEmail;
  final String? createdAt;

  bool get isChangesRequested => decision == 'changes_requested';
  bool get isApproved => decision == 'approved';
  bool get isSubmitted => decision == 'submitted';
  bool get isWithdrawn => decision == 'withdrawn';

  factory BookReviewNote.fromJson(Map<String, dynamic> j) {
    return BookReviewNote(
      id: j['id'] as String? ?? '',
      decision: j['decision'] as String? ?? '',
      comment: j['comment'] as String? ?? '',
      commentPlain: j['comment_plain'] as String? ?? '',
      reviewerId: j['reviewer_id'] as String?,
      reviewerEmail: j['reviewer_email'] as String?,
      createdAt: j['created_at'] as String?,
    );
  }
}

class AdminDraftChapter {
  AdminDraftChapter({
    required this.chapterKey,
    required this.title,
    required this.pages,
  });

  final String chapterKey;
  final String title;
  final List<AdminDraftPage> pages;

  factory AdminDraftChapter.fromJson(Map<String, dynamic> j) {
    final rawPages = j['pages'];
    final pages = rawPages is List
        ? rawPages
            .whereType<Map>()
            .map((e) => AdminDraftPage.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdminDraftPage>[];
    return AdminDraftChapter(
      chapterKey: j['chapter_key'] as String? ?? '',
      title: j['title'] as String? ?? '',
      pages: pages,
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_key': chapterKey,
        'title': title,
        'pages': pages.map((e) => e.toJson()).toList(),
      };

  /// Payload for admin save — keys and page numbers are assigned by the API.
  Map<String, dynamic> toDraftPayload() => {
        'title': title,
        'pages': pages.map((e) => e.toDraftPayload()).toList(),
      };
}

class AdminDraftPage {
  AdminDraftPage({
    required this.pageNumber,
    required this.title,
    required this.body,
  });

  final int pageNumber;
  final String title;
  final String body;

  factory AdminDraftPage.fromJson(Map<String, dynamic> j) {
    return AdminDraftPage(
      pageNumber: (j['page_number'] as num?)?.toInt() ?? 1,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'page_number': pageNumber,
        'title': title,
        'body': body,
      };

  /// Payload for admin save — page numbers are assigned by the API.
  Map<String, dynamic> toDraftPayload() => {
        'title': title,
        'body': body,
      };
}
