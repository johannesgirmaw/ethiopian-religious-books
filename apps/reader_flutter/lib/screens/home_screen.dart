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
    final offlineCount =
        ref.watch(offlineBookCountProvider).valueOrNull ?? 0;
    final downloadJobs =
        ref.watch(downloadJobsProvider).valueOrNull ?? const [];
    final inProgressCount = downloadJobs
        .where((j) => j.state == 'in_progress' || j.state == 'pending')
        .length;

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
          final featured = page.items.take(6).toList();

          return Column(
            children: [
              HomeHeroHeader(
                title: l10n.appTitle,
                subtitle: l10n.splashTagline,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(catalogProvider);
                    ref.invalidate(lastOpenedBookProvider);
                    ref.invalidate(offlineBookCountProvider);
                    ref.invalidate(offlineDownloadsListProvider);
                    ref.invalidate(downloadJobsProvider);
                    await ref.read(catalogProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      // Quick-access hub cards
                      SummaryHubCard(
                        title: l10n.homeQuickBrowse,
                        categoryLabel:
                            l10n.headerCategoriesStat(catCount),
                        categoryIcon: Icons.category_outlined,
                        contentLabel: l10n.headerBooksStat(bookCount),
                        contentIcon: Icons.library_books_outlined,
                        onTap: () => context.go('/library'),
                      ),
                      const SizedBox(height: 12),
                      SummaryHubCard(
                        title: l10n.homeQuickDownloads,
                        categoryLabel: inProgressCount > 0
                            ? l10n.inProgressDownloads
                            : l10n.downloadOffline,
                        categoryIcon: Icons.download_outlined,
                        contentLabel: offlineCount > 0
                            ? l10n.offlineBooksSaved(offlineCount)
                            : l10n.homeQuickDownloadsSubtitle,
                        contentIcon: Icons.download_done_outlined,
                        onTap: () => context.go('/downloads'),
                      ),

                      // Continue reading / featured strip
                      if (lastOpened != null &&
                          lastOpened.bookId.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _ContinueSection(
                          lastOpened: lastOpened,
                          featured: featured,
                        ),
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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitleBar(title: l10n.resumeReading),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (featured.length + 1).clamp(1, 7),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return CompactBookStripCard(
                    title: lastOpened.title,
                    onTap: () =>
                        context.push('/reader/${lastOpened.bookId}'),
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
          const SizedBox(height: 14),
          // Gradient CTA
          GestureDetector(
            onTap: () =>
                context.push('/reader/${lastOpened.bookId}'),
            child: Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                boxShadow: AppShadows.floatingBtn,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.resumeReading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
