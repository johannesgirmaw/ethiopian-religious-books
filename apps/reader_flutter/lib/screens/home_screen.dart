import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../utils/format_catalog_cache_age.dart';
import '../widgets/app_state_view.dart';
import '../widgets/app_section_card.dart';
import '../widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.searchTooltip,
            onPressed: () => context.go('/library'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return AppStateView(
              title: l10n.homeNoBooksTitle,
              message: l10n.homeNoBooksMessage,
              icon: Icons.menu_book_outlined,
              actionLabel: l10n.openLibrary,
              onAction: () => context.go('/library'),
            );
          }

          final featured = page.items.take(5).toList();
          final byLanguage = _groupByLanguage(page.items, l10n);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(catalogProvider);
              await ref.read(catalogProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (cachedAt != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_done_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.catalogSynced(
                              formatCatalogCacheAge(l10n, cachedAt),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.exploreWisdomTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.exploreWisdomBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => context.go('/library'),
                            icon: const Icon(Icons.search_rounded),
                            label: Text(l10n.searchLibrary),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/library'),
                            icon: const Icon(Icons.menu_book_outlined),
                            label: Text(l10n.browseCollections),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  l10n.featuredBooks,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.curatedSelections(featured.length),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final b = featured[index];
                      return _FeaturedBookCard(book: b);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      l10n.librarySections,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/library'),
                      child: Text(l10n.viewAll),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...byLanguage.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 146,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: entry.value.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final book = entry.value[i];
                              return _CategoryCard(book: book);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SkeletonCardGroup(count: 5),
        error: (e, _) => AppStateView(
          title: l10n.unableToLoadHome,
          message: '$e',
          icon: Icons.cloud_off_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(catalogProvider),
        ),
      ),
    );
  }

  Map<String, List<BookSummary>> _groupByLanguage(
    List<BookSummary> books,
    AppLocalizations l10n,
  ) {
    final map = <String, List<BookSummary>>{};
    for (final book in books) {
      final key = (book.primaryLanguage ?? '').trim().isEmpty
          ? l10n.generalCategory
          : book.primaryLanguage!.trim();
      map.putIfAbsent(key, () => []);
      map[key]!.add(book);
    }
    return map;
  }
}

class _FeaturedBookCard extends StatelessWidget {
  const _FeaturedBookCard({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/book/${book.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.primaryLanguage ?? l10n.generalCategory,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  book.summary ?? l10n.noSummaryYet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.readDetails),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 0,
        color: AppColors.surfaceSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/book/${book.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.authorCompiler?.isNotEmpty == true
                      ? book.authorCompiler!
                      : l10n.unknownAuthor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  l10n.openArticle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
