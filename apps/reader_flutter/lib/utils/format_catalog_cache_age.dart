import '../l10n/app_localizations.dart';

String formatCatalogCacheAge(AppLocalizations l10n, DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return l10n.cachedJustNow;
  if (diff.inHours < 1) return l10n.cachedMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.cachedHoursAgo(diff.inHours);
  return l10n.cachedDaysAgo(diff.inDays);
}
