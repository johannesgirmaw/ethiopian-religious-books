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
