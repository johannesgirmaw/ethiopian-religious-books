class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.isSuperuser = false,
    this.displayName,
    this.preferredUiLanguage,
  });

  final String id;
  final String email;
  final String role;
  final bool isSuperuser;
  final String? displayName;
  final String? preferredUiLanguage;

  /// May administer the whole platform (orders, settings, every book).
  bool get isPlatformAdmin => isSuperuser || role == 'admin';

  /// Has the author role (manages their own books and sees earnings).
  bool get isAuthor => role == 'author';

  /// May open the book-management area: admins (all books) or authors (own).
  bool get canManageBooks => isPlatformAdmin || isAuthor;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: j['id'] as String,
      email: j['email'] as String,
      role: j['role'] as String? ?? 'reader',
      isSuperuser: j['is_superuser'] as bool? ?? false,
      displayName: j['display_name'] as String?,
      preferredUiLanguage: j['preferred_ui_language'] as String?,
    );
  }
}
