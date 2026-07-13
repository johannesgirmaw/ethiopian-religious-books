// An author application (a reader's request to become an author) and the
// wrappers the API returns around it. Hand-written JSON, mirroring the other
// DTOs in this folder.

class AuthorApplication {
  AuthorApplication({
    required this.id,
    required this.fullName,
    required this.penName,
    required this.title,
    required this.bio,
    required this.phone,
    required this.country,
    required this.photoObjectKey,
    required this.photoUrl,
    required this.credentials,
    required this.sampleLinks,
    required this.paymentEmail,
    required this.telebirrNumber,
    required this.status,
    required this.reviewNote,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    // Admin-only fields (present on the review queue serializer).
    this.userId,
    this.userEmail,
    this.userDisplayName,
  });

  final String id;
  final String fullName;
  final String penName;
  final String title;
  final String bio;
  final String phone;
  final String country;
  final String photoObjectKey;
  final String photoUrl;
  final String credentials;
  final String sampleLinks;
  final String paymentEmail;
  final String telebirrNumber;
  final String status;
  final String reviewNote;
  final String? reviewedAt;
  final String? createdAt;
  final String? updatedAt;

  final String? userId;
  final String? userEmail;
  final String? userDisplayName;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory AuthorApplication.fromJson(Map<String, dynamic> j) {
    return AuthorApplication(
      id: _str(j['id']),
      fullName: _str(j['full_name']),
      penName: _str(j['pen_name']),
      title: _str(j['title']),
      bio: _str(j['bio']),
      phone: _str(j['phone']),
      country: _str(j['country']),
      photoObjectKey: _str(j['photo_object_key']),
      photoUrl: _str(j['photo_url']),
      credentials: _str(j['credentials']),
      sampleLinks: _str(j['sample_links']),
      paymentEmail: _str(j['payment_email']),
      telebirrNumber: _str(j['telebirr_number']),
      status: (j['status'] as String?) ?? 'pending',
      reviewNote: _str(j['review_note']),
      reviewedAt: j['reviewed_at'] as String?,
      createdAt: j['created_at'] as String?,
      updatedAt: j['updated_at'] as String?,
      userId: j['user'] as String?,
      userEmail: j['user_email'] as String?,
      userDisplayName: j['user_display_name'] as String?,
    );
  }

  /// Writable payload for submitting/editing the application. Omits blank
  /// optional values so a partial edit never clobbers stored fields with "".
  Map<String, dynamic> toPayload() {
    final map = <String, dynamic>{'full_name': fullName.trim()};
    void put(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) map[key] = v;
    }

    put('pen_name', penName);
    put('title', title);
    put('bio', bio);
    put('phone', phone);
    put('country', country);
    put('photo_object_key', photoObjectKey);
    put('credentials', credentials);
    put('sample_links', sampleLinks);
    put('payment_email', paymentEmail);
    put('telebirr_number', telebirrNumber);
    return map;
  }
}

/// Response of `GET /author/application` — the caller's own application (may be
/// null) plus whether they are already an author.
class MyAuthorApplication {
  MyAuthorApplication({required this.application, required this.isAuthor});

  final AuthorApplication? application;
  final bool isAuthor;

  factory MyAuthorApplication.fromJson(Map<String, dynamic> j) {
    final app = j['application'];
    return MyAuthorApplication(
      application: app is Map<String, dynamic>
          ? AuthorApplication.fromJson(app)
          : null,
      isAuthor: j['is_author'] as bool? ?? false,
    );
  }
}

/// Response of `GET /admin/author-applications` — the review queue.
class AuthorApplicationsPage {
  AuthorApplicationsPage({required this.items, required this.pending});

  final List<AuthorApplication> items;
  final int pending;

  factory AuthorApplicationsPage.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AuthorApplication.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AuthorApplication>[];
    return AuthorApplicationsPage(
      items: items,
      pending: (j['pending'] as num?)?.toInt() ?? 0,
    );
  }
}
