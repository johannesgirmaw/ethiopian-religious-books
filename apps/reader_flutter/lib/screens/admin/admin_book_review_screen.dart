import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../widgets/book_review_history_view.dart';

/// Review-round history for a book. Shared across platforms (like the admin
/// book editor): shows every submit / approve / change-request / withdraw with
/// the reviewer's rich-text comments. Reached from the book-management list's
/// "View feedback" action and the editor's change-request banner.
class AdminBookReviewScreen extends ConsumerWidget {
  const AdminBookReviewScreen({
    super.key,
    required this.bookId,
    this.initialBook,
  });

  final String bookId;
  final AdminBook? initialBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewHistoryTitle),
      ),
      body: SafeArea(
        child: BookReviewHistoryView(bookId: bookId),
      ),
    );
  }
}
