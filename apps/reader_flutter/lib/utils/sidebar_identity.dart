import '../models/user_profile.dart';

/// Shared helpers for the shell sidebars' footer identity card (web + desktop).

/// Display name for the signed-in user: their display name, else the local part
/// of their email, else a placeholder.
String sidebarUserName(UserProfile? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final email = user?.email ?? '';
  final at = email.indexOf('@');
  if (at > 0) return email.substring(0, at);
  return email.isNotEmpty ? email : '—';
}

/// Muted second line under the name — the user's email.
String sidebarUserSubtitle(UserProfile? user) {
  final email = user?.email.trim();
  return (email != null && email.isNotEmpty) ? email : '—';
}

/// First code point of [name], upper-cased, for the avatar.
String sidebarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
