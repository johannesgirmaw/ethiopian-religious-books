import '../l10n/app_localizations.dart';

/// Reasonable email shape check (not RFC-perfect, but rejects the common
/// mistakes a loose `contains('@')` lets through: spaces, missing local part,
/// missing/short TLD, trailing dots).
///
/// Also accepts `@localhost` — that is the documented local seed login
/// (`reader@localhost`, `admin@localhost`).
final RegExp _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r"(?:"
  r"localhost"
  r"|"
  r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
  r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+"
  r")$",
);

/// Shared email validator for auth forms. Returns a localized message or null.
String? validateEmail(String? value, AppLocalizations l10n) {
  final s = (value ?? '').trim();
  if (s.isEmpty) return l10n.emailRequired;
  if (!_emailRegExp.hasMatch(s)) return l10n.emailInvalid;
  return null;
}

/// Ethiopian-friendly phone validator (local or E.164).
String? validatePhone(String? value, AppLocalizations l10n) {
  final s = (value ?? '').trim();
  if (s.isEmpty) return l10n.phoneRequired;
  final digits = s.replaceAll(RegExp(r'\D'), '');
  final ok = digits.length >= 9 && digits.length <= 15;
  if (!ok) return l10n.phoneInvalid;
  return null;
}
