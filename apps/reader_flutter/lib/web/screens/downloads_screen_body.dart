import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../design/web_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_job.dart';
import '../../models/offline_cached_book.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/download_jobs_provider.dart';
import '../../storage/book_content_cache_storage.dart';
import '../../utils/offline_book_download.dart';
import '../../widgets/app_state_view.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

Future<void> _syncOfflineBookCache(WidgetRef ref, String bookId) async {
  ref.invalidate(bookContentProvider(bookId));
  await ref.read(bookContentProvider(bookId).future);
  try {
    await ref.read(bookDetailProvider(bookId).future);
  } on DioException {}
  ref.invalidate(offlineDownloadsListProvider);
  ref.invalidate(offlineBookCountProvider);
}

class DownloadsScreenBody extends ConsumerWidget {
  const DownloadsScreenBody({super.key});

  Future<void> _confirmClearAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearOfflineCacheTitle),
        content: Text(l10n.clearOfflineCacheBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.clear)),
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offlineAsync = ref.watch(offlineDownloadsListProvider);
    final jobsAsync = ref.watch(downloadJobsProvider);
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));

    return offlineAsync.when(
      data: (offlineBooks) {
        final jobs = jobsAsync.valueOrNull ?? const <DownloadJob>[];
        final activeJobs =
            jobs.where((j) => j.state == 'in_progress' || j.state == 'pending').toList();
        final failedJobs = jobs.where((j) => j.state == 'failed').toList();

        if (offlineBooks.isEmpty && activeJobs.isEmpty && failedJobs.isEmpty) {
          return ListView(
            padding: padding,
            children: [
              WebPageHeader(
                title: l10n.downloadsPageTitle,
                subtitle: l10n.downloadsEmptyMessage,
              ),
              const SizedBox(height: 28),
              WebEmptyState(
                icon: Icons.download_outlined,
                title: l10n.downloadsEmptyTitle,
                message: l10n.downloadsEmptyMessage,
                action: FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.local_library_outlined, size: 18),
                  label: Text(l10n.openLibrary),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(offlineDownloadsListProvider);
            ref.invalidate(downloadJobsProvider);
            await ref.read(offlineDownloadsListProvider.future);
          },
          child: ListView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              WebPageHeader(
                title: l10n.downloadsPageTitle,
                subtitle: l10n.offlineBooksSaved(offlineBooks.length),
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmClearAll(context, ref, l10n),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(l10n.downloadsClearAllCache),
                  ),
                ],
              ),
              if (activeJobs.isNotEmpty) ...[
                const SizedBox(height: 28),
                WebSection(
                  title: l10n.downloadsActiveSection.toUpperCase(),
                  child: WebPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < activeJobs.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _JobRow(job: activeJobs[i], failed: false),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (failedJobs.isNotEmpty) ...[
                const SizedBox(height: 24),
                WebSection(
                  title: l10n.downloadsFailedSection.toUpperCase(),
                  child: WebPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < failedJobs.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _JobRow(job: failedJobs[i], failed: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (offlineBooks.isNotEmpty) ...[
                const SizedBox(height: 24),
                WebSection(
                  title: l10n.downloadsSavedSection.toUpperCase(),
                  child: WebPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < offlineBooks.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _OfflineRow(entry: offlineBooks[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => ListView(
        padding: padding,
        children: [
          WebPageHeader(
            title: l10n.downloadsPageTitle,
            subtitle: l10n.downloadsEmptyMessage,
          ),
          const SizedBox(height: 24),
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )),
        ],
      ),
      error: (e, _) => ListView(
        padding: padding,
        children: [
          WebPageHeader(title: l10n.downloadsPageTitle),
          const SizedBox(height: 24),
          AppStateView(
            title: l10n.unableToLoadDownloads,
            message: '$e',
            icon: Icons.cloud_off_outlined,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(offlineDownloadsListProvider),
          ),
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job, required this.failed});

  final DownloadJob job;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final matches = catalog?.items.where((b) => b.id == job.bookId).toList() ?? [];
    final title = matches.isNotEmpty ? matches.first.title : job.bookId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(failed ? Icons.error_outline : Icons.downloading, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (failed)
            TextButton(
              onPressed: () async {
                await runOfflineBookDownload(ref, job.bookId, l10n: l10n);
                ref.invalidate(downloadJobsProvider);
              },
              child: Text(l10n.retry),
            )
          else
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _OfflineRow extends ConsumerWidget {
  const _OfflineRow({required this.entry});

  final OfflineCachedBook entry;

  /// Drops just this book's offline copy, leaving the rest of the cache intact.
  Future<void> _clearBook(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloadsClearBookTitle(entry.title)),
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
    await BookContentCacheStorage.removeBookContent(entry.id);
    ref.invalidate(offlineDownloadsListProvider);
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineBookCachedProvider(entry.id));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offlineCopyRemoved)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (entry.authorCompiler?.isNotEmpty == true)
                  Text(entry.authorCompiler!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: entry.hasReadableContent
                ? () => context.push('/reader/${entry.id}')
                : null,
            child: Text(l10n.actionRead),
          ),
          TextButton(
            onPressed: () => _syncOfflineBookCache(ref, entry.id),
            child: Text(l10n.downloadsSyncCache),
          ),
          IconButton(
            tooltip: l10n.downloadsClearBookCache,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () => _clearBook(context, ref, l10n),
          ),
        ],
      ),
    );
  }
}
