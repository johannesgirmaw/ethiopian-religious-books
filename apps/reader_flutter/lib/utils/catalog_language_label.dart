import '../l10n/app_localizations.dart';

/// Maps catalog [primaryLanguage] codes to human-readable filter labels.
String catalogLanguageFilterKey(String? primaryLanguage, AppLocalizations l10n) {
  final raw = (primaryLanguage ?? '').trim().toLowerCase();
  if (raw.isEmpty) return l10n.generalCategory;
  return raw;
}

String catalogLanguageFilterLabel(String? primaryLanguage, AppLocalizations l10n) {
  final raw = (primaryLanguage ?? '').trim().toLowerCase();
  return switch (raw) {
    'am' => l10n.catalogLanguageAmharic,
    'gez' => l10n.catalogLanguageGeez,
    'en' => l10n.catalogLanguageEnglish,
    '' => l10n.generalCategory,
    _ => primaryLanguage!.trim(),
  };
}
