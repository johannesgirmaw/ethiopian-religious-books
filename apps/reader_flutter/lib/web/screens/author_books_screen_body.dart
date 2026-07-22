import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/engagement_providers.dart';
import '../design/web_tokens.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/catalog/web_book_card.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

class AuthorBooksScreenBody extends ConsumerWidget {
  const AuthorBooksScreenBody({super.key, required this.author});

  final String author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));
    final async = ref.watch(booksByAuthorProvider(author));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: padding,
        child: WebEmptyState(
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
                WebPageHeader(title: author),
                const SizedBox(height: 28),
                WebEmptyState(
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
                child: WebPageHeader(
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
                gridDelegate: catalogGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => WebBookCard(book: books[i], index: i),
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
