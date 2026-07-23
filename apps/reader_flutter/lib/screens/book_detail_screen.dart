import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/book_detail_body.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../mobile/screens/mobile_book_detail_screen.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../router/app_navigation.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/book_detail_body.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  void _shareBook(BuildContext context, BookSummary book) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: book.title));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bookSharedToClipboard)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncBook = ref.watch(bookDetailProvider(bookId));

    // Cold-open fallback: if this turns out to be a Bible book (e.g. deep link
    // opened before the catalog was cached), send it to the verse reader. The
    // /book/:id route redirect handles the common (catalog-loaded) case.
    final loadedBook = asyncBook.valueOrNull;
    if (loadedBook != null && loadedBook.isBible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/bible/book/$bookId');
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOverlayRoute(context);
      },
      child: AppLayoutScopeBuilder(
        child: Builder(
          builder: (context) {
            if (useWebShell(context)) {
              return WebOverlayScaffold(
                title: l10n.bookDetailsTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                actions: [
                  asyncBook.maybeWhen(
                    data: (book) => IconButton(
                      tooltip: l10n.shareBookTooltip,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => _shareBook(context, book),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
                body: BookDetailBody(
                  bookId: bookId,
                  onShare: (book) => _shareBook(context, book),
                ),
              );
            }

            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: l10n.bookDetailsTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                actions: [
                  asyncBook.maybeWhen(
                    data: (book) => IconButton(
                      tooltip: l10n.shareBookTooltip,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => _shareBook(context, book),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
                body: DesktopBookDetailBody(
                  bookId: bookId,
                  onShare: (book) => _shareBook(context, book),
                ),
              );
            }

            return MobileBookDetailScreen(bookId: bookId);
          },
        ),
      ),
    );
  }
}
