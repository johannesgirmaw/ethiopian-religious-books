import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/reader_prefs_storage.dart';
import '../widgets/app_state_view.dart';
import '../widgets/reference/compact_book_strip_card.dart';
import '../widgets/reference/home_hero_header.dart';
import '../widgets/reference/section_title_bar.dart';
import '../widgets/reference/summary_hub_card.dart';
import '../widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  int _languageCategoryCount(List<BookSummary> books, AppLocalizations l10n) {
    return books
        .map((b) => (b.primaryLanguage ?? '').trim().isEmpty
            ? l10n.generalCategory
            : b.primaryLanguage!.trim())
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final downloadCount = ref.watch(downloadJobsProvider).valueOrNull
            ?.where((j) => j.state == 'completed')
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      body: async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return Column(
              children: [
                HomeHeroHeader(title: l10n.appTitle),
                Expanded(
                  child: AppStateView(
                    title: l10n.homeNoBooksTitle,
                    message: l10n.homeNoBooksMessage,
                    icon: Icons.menu_book_outlined,
                    actionLabel: l10n.openLibrary,
                    onAction: () => context.go('/library'),
                  ),
                ),
              ],
            );
          }

          final catCount = _languageCategoryCount(page.items, l10n);
          final bookCount = page.items.length;
          final featured = page.items.take(5).toList();

          return Column(
            children: [
              HomeHeroHeader(
                title: l10n.appTitle,
                subtitle: l10n.splashTagline,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(catalogProvider);
                    ref.invalidate(lastOpenedBookProvider);
                    await ref.read(catalogProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 40,
                    ),
                    children: [
                      SummaryHubCard(
                        title: l10n.homeQuickBrowse,
                        categoryLabel: l10n.headerCategoriesStat(catCount),
                        categoryIcon: Icons.category_outlined,
                        contentLabel: l10n.headerBooksStat(bookCount),
                        contentIcon: Icons.library_books_outlined,
                        onTap: () => context.go('/library'),
                      ),
                      const SizedBox(height: 16),
                      SummaryHubCard(
                        title: l10n.homeQuickDownloads,
                        categoryLabel: l10n.downloadOffline,
                        categoryIcon: Icons.download_outlined,
                        contentLabel: downloadCount > 0
                            ? '$downloadCount'
                            : l10n.homeQuickDownloadsSubtitle,
                        contentIcon: Icons.download_done_outlined,
                        onTap: () => context.go('/library'),
                      ),
                      if (lastOpened != null && lastOpened.bookId.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _ContinueSection(lastOpened: lastOpened, featured: featured),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            HomeHeroHeader(title: l10n.appTitle),
            const Expanded(child: SkeletonCardGroup(count: 3)),
          ],
        ),
        error: (e, _) => Column(
          children: [
            HomeHeroHeader(title: l10n.appTitle),
            Expanded(
              child: AppStateView(
                title: l10n.unableToLoadHome,
                message: '$e',
                icon: Icons.cloud_off_outlined,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(catalogProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  const _ContinueSection({
    required this.lastOpened,
    required this.featured,
  });

  final LastOpenedBook lastOpened;
  final List<BookSummary> featured;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitleBar(title: l10n.mostReadSection),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (featured.length + 1).clamp(1, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return CompactBookStripCard(
                    title: lastOpened.title,
                    onTap: () => context.push('/reader/${lastOpened.bookId}'),
                  );
                }
                final book = featured[(index - 1) % featured.length];
                return CompactBookStripCard(
                  title: book.title,
                  onTap: () => context.push('/reader/${book.id}'),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.referencePrimary,
                foregroundColor: Colors.black87,
              ),
              onPressed: () => context.push('/reader/${lastOpened.bookId}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.resumeReading),
            ),
          ),
        ],
      ),
    );
  }
}
