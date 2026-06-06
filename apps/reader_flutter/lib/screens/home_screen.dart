import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/download_jobs_provider.dart';
import '../providers/session_notifier.dart';
import '../storage/reader_prefs_storage.dart';
import '../widgets/app_state_view.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/reference/compact_book_strip_card.dart';
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

  String _greetingTitle(AppLocalizations l10n, Session? session) {
    final name = session?.user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return l10n.appTitle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
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
      body: SafeArea(
        bottom: false,
        child: async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return _HomeScroll(
              onRefresh: () => _refresh(ref),
              children: [
                AppGreetingCard(
                  greetingLine: greetingForL10n(l10n),
                  title: _greetingTitle(l10n, session),
                  subtitle: l10n.splashTagline,
                ),
                AppStateView(
                  title: l10n.homeNoBooksTitle,
                  message: l10n.homeNoBooksMessage,
                  icon: Icons.menu_book_outlined,
                  actionLabel: l10n.openLibrary,
                  onAction: () => context.go('/library'),
                ),
              ],
            );
          }

          final catCount = _languageCategoryCount(page.items, l10n);
          final bookCount = page.items.length;
          final featured = page.items.take(6).toList();

          return _HomeScroll(
            onRefresh: () => _refresh(ref),
            children: [
              AppGreetingCard(
                greetingLine: greetingForL10n(l10n),
                title: _greetingTitle(l10n, session),
                subtitle: l10n.splashTagline,
              ),
              AppActionRail(
                items: [
                  AppActionRailItem(
                    icon: Icons.library_books_outlined,
                    label: l10n.homeQuickBrowse,
                    onTap: () => context.go('/library'),
                  ),
                  AppActionRailItem(
                    icon: Icons.download_outlined,
                    label: l10n.homeQuickDownloads,
                    accent: AppColors.primaryMid,
                    onTap: () => context.go('/downloads'),
                  ),
                  if (lastOpened != null && lastOpened.bookId.isNotEmpty)
                    AppActionRailItem(
                      icon: Icons.play_arrow_rounded,
                      label: l10n.resumeReading,
                      accent: AppColors.successText,
                      onTap: () =>
                          context.push('/reader/${lastOpened.bookId}'),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    AppHeroMetric(
                      label: l10n.homeQuickBrowse,
                      value: '$bookCount',
                      chip: AppStatusChip(
                        label: l10n.headerCategoriesStat(catCount),
                        kind: AppStatusKind.accent,
                      ),
                      footer: Text(
                        l10n.headerBooksStat(bookCount),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => context.go('/library'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppStatTile(
                            icon: Icons.download_outlined,
                            label: l10n.downloadOffline,
                            value: '$offlineCount',
                            hint: offlineCount > 0
                                ? l10n.offlineBooksSaved(offlineCount)
                                : l10n.homeQuickDownloadsSubtitle,
                            accent: AppColors.primaryMid,
                            onTap: () => context.go('/downloads'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppStatTile(
                            icon: Icons.sync_rounded,
                            label: l10n.inProgressDownloads,
                            value: '$inProgressCount',
                            hint: inProgressCount > 0
                                ? l10n.inProgressDownloads
                                : null,
                            accent: inProgressCount > 0
                                ? const Color(0xFF92660B)
                                : AppColors.textTertiary,
                            onTap: () => context.go('/downloads'),
                          ),
                        ),
                      ],
                    ),
                    if (lastOpened != null &&
                        lastOpened.bookId.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _ContinueSection(
                        lastOpened: lastOpened,
                        featured: featured,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => _HomeScroll(
          onRefresh: () => _refresh(ref),
          children: [
            AppGreetingCard(
              greetingLine: greetingForL10n(l10n),
              title: l10n.appTitle,
              subtitle: l10n.splashTagline,
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonCardGroup(count: 3),
            ),
          ],
        ),
        error: (e, _) => _HomeScroll(
          onRefresh: () => _refresh(ref),
          children: [
            AppGreetingCard(
              greetingLine: greetingForL10n(l10n),
              title: l10n.appTitle,
              subtitle: l10n.splashTagline,
            ),
            AppStateView(
              title: l10n.unableToLoadHome,
              message: '$e',
              icon: Icons.cloud_off_outlined,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(catalogProvider),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogProvider);
    ref.invalidate(lastOpenedBookProvider);
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineDownloadsListProvider);
    ref.invalidate(downloadJobsProvider);
    await ref.read(catalogProvider.future);
  }
}

class _HomeScroll extends StatelessWidget {
  const _HomeScroll({
    required this.onRefresh,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
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
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l10n.continueReading),
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
                  onTap: () => context.push('/book/${book.id}'),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () =>
                context.push('/reader/${lastOpened.bookId}'),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(l10n.resumeReading),
          ),
        ],
      ),
    );
  }
}
