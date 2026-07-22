import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/platform/platform_shell.dart';
import '../../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../router/app_navigation.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/widgets/shell/web_overlay_scaffold.dart';
import '../../widgets/book_review_history_view.dart';

/// Review-round history for a book. Shared form body; platform overlay chrome
/// on web/desktop. Reached from the book-management list's "View feedback"
/// action and the editor's change-request banner.
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
    final body = SafeArea(
      child: BookReviewHistoryView(bookId: bookId),
    );

    if (useWebShell(context)) {
      return WebOverlayScaffold(
        title: l10n.reviewHistoryTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        appTitle: l10n.appTitle,
        onBack: () => popOverlayRoute(context),
        body: body,
      );
    }

    if (useDesktopShell(context)) {
      return DesktopOverlayScaffold(
        title: l10n.reviewHistoryTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        appTitle: l10n.appTitle,
        onBack: () => popOverlayRoute(context),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewHistoryTitle),
      ),
      body: body,
    );
  }
}
