import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/engagement_providers.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/catalog/desktop_book_card.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_section.dart';

class DesktopAuthorBooksScreenBody extends ConsumerWidget {
  const DesktopAuthorBooksScreenBody({super.key, required this.author});

  final String author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));
    final async = ref.watch(booksByAuthorProvider(author));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: padding,
        child: DesktopEmptyState(
          icon: Icons.person_outline_rounded,
          title: author,
          message: '$e',
        ),
      ),
      data: (books) {
        if (books.isEmpty) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopPageHeader(title: author),
                const SizedBox(height: 20),
                DesktopEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: author,
                  message: l10n.noMatchingBooksMessage,
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(
                child: DesktopPageHeader(
                  title: author,
                  subtitle: '${books.length}',
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                8,
                padding.right,
                padding.bottom,
              ),
              sliver: SliverGrid(
                gridDelegate: desktopCatalogGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => DesktopBookCard(book: books[i], index: i),
                  childCount: books.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
