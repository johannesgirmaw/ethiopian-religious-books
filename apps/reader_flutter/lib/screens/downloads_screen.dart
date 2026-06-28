import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/download_job.dart';
import '../models/offline_cached_book.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/book_content_cache_storage.dart';
import '../utils/offline_book_download.dart';
import '../widgets/app_state_view.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/screens/downloads_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/downloads_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';
import '../widgets/shell_page_scaffold.dart';

Future<void> _syncOfflineBookCache(WidgetRef ref, String bookId) async {
  ref.invalidate(bookContentProvider(bookId));
  await ref.read(bookContentProvider(bookId).future);
  try {
    await ref.read(bookDetailProvider(bookId).future);
  } on DioException {
    // Meta update is best-effort when offline.
  }
  ref.invalidate(offlineDownloadsListProvider);
  ref.invalidate(offlineBookCountProvider);
  ref.invalidate(offlineBookCachedProvider(bookId));
  ref.invalidate(bookDetailProvider(bookId));
}

/// Offline downloads hub — saved books and active download jobs (not the full catalog).
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return WebPageScaffold(body: const DownloadsScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopDownloadsScreenBody());
    }

    final l10n = AppLocalizations.of(context)!;
    final offlineAsync = ref.watch(offlineDownloadsListProvider);
    final jobsAsync = ref.watch(downloadJobsProvider);

    return ShellPageScaffold(
      title: l10n.downloadsPageTitle,
      showBackButton: true,
      onBack: () => context.go('/settings'),
      actions: [
        IconButton(
          tooltip: l10n.downloadsClearAllCache,
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.clearOfflineCacheTitle),
                content: Text(l10n.clearOfflineCacheBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.clear),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            await BookContentCacheStorage.clearAll();
            ref.invalidate(offlineDownloadsListProvider);
            ref.invalidate(offlineBookCountProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.offlineCacheCleared)),
              );
            }
          },
        ),
      ],
      body: offlineAsync.when(
        data: (offlineBooks) {
          final jobs = jobsAsync.valueOrNull ?? const <DownloadJob>[];
          final activeJobs = jobs
              .where((j) => j.state == 'in_progress' || j.state == 'pending')
              .toList();
          final failedJobs =
              jobs.where((j) => j.state == 'failed').toList();

          if (offlineBooks.isEmpty &&
              activeJobs.isEmpty &&
              failedJobs.isEmpty) {
            return AppStateView(
              title: l10n.downloadsEmptyTitle,
              message: l10n.downloadsEmptyMessage,
              icon: Icons.download_outlined,
              actionLabel: l10n.openLibrary,
              onAction: () => context.go('/home'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(offlineDownloadsListProvider);
              ref.invalidate(offlineBookCountProvider);
              ref.invalidate(downloadJobsProvider);
              await ref.read(offlineDownloadsListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  l10n.offlineBooksSaved(offlineBooks.length),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                if (activeJobs.isNotEmpty) ...[
                  AppSectionHeader(title: l10n.downloadsActiveSection),
                  const SizedBox(height: 8),
                  ...activeJobs.map(
                    (job) => _DownloadJobTile(job: job, isFailed: false),
                  ),
                  const SizedBox(height: 16),
                ],
                if (failedJobs.isNotEmpty) ...[
                  AppSectionHeader(title: l10n.downloadsFailedSection),
                  const SizedBox(height: 8),
                  ...failedJobs.map(
                    (job) => _DownloadJobTile(job: job, isFailed: true),
                  ),
                  const SizedBox(height: 16),
                ],
                if (offlineBooks.isNotEmpty) ...[
                  AppSectionHeader(title: l10n.downloadsSavedSection),
                  const SizedBox(height: 8),
                  ...offlineBooks.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OfflineBookCard(entry: entry),
                    ),
                  ),
                ] else if (activeJobs.isEmpty && failedJobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.downloadsNoSavedYet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: l10n.unableToLoadDownloads,
          message: '$e',
          icon: Icons.cloud_off_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(offlineDownloadsListProvider),
        ),
      ),
    );
  }
}

class _OfflineBookCard extends ConsumerStatefulWidget {
  const _OfflineBookCard({required this.entry});

  final OfflineCachedBook entry;

  @override
  ConsumerState<_OfflineBookCard> createState() => _OfflineBookCardState();
}

class _OfflineBookCardState extends ConsumerState<_OfflineBookCard> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      await _syncOfflineBookCache(ref, widget.entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.downloadsSyncDone),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloadsClearBookTitle(widget.entry.title)),
        content: Text(l10n.downloadsClearBookBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await BookContentCacheStorage.removeBookContent(widget.entry.id);
    ref.invalidate(offlineDownloadsListProvider);
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineBookCachedProvider(widget.entry.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.offlineCopyRemoved)),
      );
    }
  }

  void _showOfflineInfo() {
    final l10n = AppLocalizations.of(context)!;
    final e = widget.entry;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (e.authorCompiler?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(e.authorCompiler!),
              ],
              const SizedBox(height: 12),
              Text(l10n.draftChapterPageCounts(e.chapterCount, e.pageCount)),
              if (!e.hasReadableContent) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.downloadsCacheInvalid,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
              if (!e.inCatalog) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.downloadsNotInCatalogHint,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final e = widget.entry;
    final theme = Theme.of(context);

    return AppPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (e.authorCompiler?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.authorCompiler!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (e.primaryLanguage?.isNotEmpty == true)
                            e.primaryLanguage!,
                          l10n.draftChapterPageCounts(
                            e.chapterCount,
                            e.pageCount,
                          ),
                          if (!e.hasReadableContent) l10n.downloadsCacheInvalid,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: e.hasReadableContent
                              ? AppColors.textSecondary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: l10n.adminBookActionsTooltip,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) async {
                      switch (action) {
                        case 'read':
                          if (e.hasReadableContent) {
                            context.push('/reader/${e.id}');
                          }
                        case 'info':
                          if (e.inCatalog) {
                            context.push('/book/${e.id}');
                          } else {
                            _showOfflineInfo();
                          }
                        case 'sync':
                          await _sync();
                        case 'clear':
                          await _clear();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'read',
                        enabled: e.hasReadableContent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined, size: 22),
                          title: Text(l10n.actionRead),
                          subtitle: e.hasReadableContent
                              ? null
                              : Text(l10n.downloadsCacheInvalid),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'info',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.info_outline_rounded, size: 22),
                          title: Text(l10n.actionInfo),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'sync',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.sync_rounded, size: 22),
                          title: Text(l10n.downloadsSyncCache),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            l10n.downloadsClearBookCache,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (e.hasReadableContent) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => context.push('/reader/${e.id}'),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(l10n.actionRead),
                ),
              ),
            ],
          ],
        ),
    );
  }
}

class _DownloadJobTile extends ConsumerWidget {
  const _DownloadJobTile({
    required this.job,
    required this.isFailed,
  });

  final DownloadJob job;
  final bool isFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(offlineDownloadsListProvider).valueOrNull ?? const [];
    final cached = offline.where((e) => e.id == job.bookId).toList();
    // Prefer catalog title for jobs
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final catalogMatches =
        catalog?.items.where((b) => b.id == job.bookId).toList() ?? const [];
    final displayTitle = catalogMatches.isNotEmpty
        ? catalogMatches.first.title
        : (cached.isNotEmpty ? cached.first.title : job.bookId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        padding: EdgeInsets.zero,
        child: ListTile(
        leading: Icon(
          isFailed ? Icons.error_outline_rounded : Icons.downloading_rounded,
          color: isFailed ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isFailed
              ? displayDownloadJobError(job.errorMessage, l10n)
              : l10n.downloadInProgress,
        ),
        trailing: isFailed
            ? TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.preparingDownload)),
                  );
                  final error = await runOfflineBookDownload(
                    ref,
                    job.bookId,
                    l10n: l10n,
                  );
                  if (!context.mounted) return;
                  ref.invalidate(downloadJobsProvider);
                  ref.invalidate(offlineDownloadsListProvider);
                  if (error == null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.savedOfflineReading)),
                    );
                  } else {
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  }
                },
                child: Text(l10n.retry),
              )
            : const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        onTap: () {
          if (cached.isNotEmpty && cached.first.hasReadableContent) {
            context.push('/reader/${job.bookId}');
          } else if (catalogMatches.isNotEmpty) {
            context.push('/book/${job.bookId}');
          }
        },
        ),
      ),
    );
  }
}
