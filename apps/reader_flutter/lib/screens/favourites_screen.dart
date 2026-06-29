import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../mobile/widgets/catalog/mobile_book_card.dart';
import '../providers/catalog_providers.dart';
import '../providers/engagement_providers.dart';
import '../router/app_navigation.dart';
import '../widgets/app_state_view.dart';

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final favIds = ref.watch(favouriteIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOverlayRoute(context),
        ),
        title: Text(l10n.favouritesTitle),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: favIds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: l10n.favouritesTitle,
          message: '$e',
          icon: Icons.favorite_border_rounded,
        ),
        data: (ids) {
          final books = (catalog?.items ?? [])
              .where((b) => ids.contains(b.id))
              .toList();
          if (books.isEmpty) {
            return AppStateView(
              title: l10n.favouritesEmptyTitle,
              message: l10n.favouritesEmptyMessage,
              icon: Icons.favorite_border_rounded,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: GridView.builder(
                padding: const EdgeInsets.all(AppLayout.pageHorizontal),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.62,
                ),
                itemCount: books.length,
                itemBuilder: (context, i) =>
                    MobileBookCard(book: books[i], index: i),
              ),
            ),
          );
        },
      ),
    );
  }
}
