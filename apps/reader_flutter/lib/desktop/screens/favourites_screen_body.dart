import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/engagement_providers.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/catalog/desktop_book_card.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_section.dart';

class DesktopFavouritesScreenBody extends ConsumerWidget {
  const DesktopFavouritesScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding = DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final favIds = ref.watch(favouriteIdsProvider);

    return favIds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: padding,
        child: DesktopEmptyState(
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
                DesktopPageHeader(title: l10n.favouritesTitle),
                const SizedBox(height: 20),
                DesktopEmptyState(
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
                child: DesktopPageHeader(
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
