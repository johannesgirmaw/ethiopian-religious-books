import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/engagement_providers.dart';
import '../design/web_tokens.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/catalog/web_book_card.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

class FavouritesScreenBody extends ConsumerWidget {
  const FavouritesScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final favIds = ref.watch(favouriteIdsProvider);

    return favIds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: padding,
        child: WebEmptyState(
          icon: Icons.favorite_border_rounded,
          title: l10n.favouritesTitle,
          message: '$e',
        ),
      ),
      data: (ids) {
        final books =
            (catalog?.items ?? []).where((b) => ids.contains(b.id)).toList();
        if (books.isEmpty) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebPageHeader(title: l10n.favouritesTitle),
                const SizedBox(height: 28),
                WebEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.favouritesEmptyTitle,
                  message: l10n.favouritesEmptyMessage,
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
                  title: l10n.favouritesTitle,
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
