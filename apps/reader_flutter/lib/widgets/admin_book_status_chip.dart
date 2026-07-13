import '../l10n/app_localizations.dart';
import '../models/admin_book.dart';
import 'primitives/shell_primitives.dart';

/// Maps a book's [AdminBookDisplayStatus] to the label + chip kind shown in the
/// book-management lists. Shared by the mobile/web/desktop bodies so the status
/// vocabulary stays identical across platforms (the chip widget itself is
/// rendered per platform).
(String, AppStatusKind) adminBookStatusChip(
  AppLocalizations l10n,
  AdminBookDisplayStatus status,
) {
  switch (status) {
    case AdminBookDisplayStatus.published:
      return (l10n.publishedStatus, AppStatusKind.active);
    case AdminBookDisplayStatus.reviewed:
      return (l10n.reviewedStatus, AppStatusKind.accent);
    case AdminBookDisplayStatus.inReview:
      return (l10n.inReviewStatus, AppStatusKind.pending);
    case AdminBookDisplayStatus.draft:
      return (l10n.draftStatus, AppStatusKind.neutral);
  }
}
