import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_job.dart';
import '../../models/offline_cached_book.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/download_jobs_provider.dart';
import '../../storage/book_content_cache_storage.dart';
import '../../utils/offline_book_download.dart';
import '../../widgets/app_state_view.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_scroll_body.dart';
import '../widgets/common/desktop_section.dart';

Future<void> _syncOfflineBookCache(WidgetRef ref, String bookId) async {
  ref.invalidate(bookContentProvider(bookId));
  await ref.read(bookContentProvider(bookId).future);
  try {
    await ref.read(bookDetailProvider(bookId).future);
  } on DioException {}
  ref.invalidate(offlineDownloadsListProvider);
  ref.invalidate(offlineBookCountProvider);
}

class DesktopDownloadsScreenBody extends ConsumerWidget {
  const DesktopDownloadsScreenBody({super.key});

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
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(offlineDownloadsListProvider);
    ref.invalidate(downloadJobsProvider);
    await ref.read(offlineDownloadsListProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offlineAsync = ref.watch(offlineDownloadsListProvider);
    final jobsAsync = ref.watch(downloadJobsProvider);
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));

    return offlineAsync.when(
      data: (offlineBooks) {
        final jobs = jobsAsync.valueOrNull ?? const <DownloadJob>[];
        final activeJobs = jobs
            .where((j) => j.state == 'in_progress' || j.state == 'pending')
            .toList();
        final failedJobs = jobs.where((j) => j.state == 'failed').toList();
        final isEmpty =
            offlineBooks.isEmpty &&
            activeJobs.isEmpty &&
            failedJobs.isEmpty;

        if (isEmpty) {
          return DesktopScrollBody(
            padding: padding,
            children: [
              DesktopPageHeader(
                title: l10n.downloadsPageTitle,
                subtitle: l10n.downloadsEmptyMessage,
              ),
              const SizedBox(height: 24),
              DesktopEmptyState(
                icon: Icons.download_outlined,
                title: l10n.downloadsEmptyTitle,
                message: l10n.downloadsEmptyMessage,
                action: FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.local_library_outlined, size: 16),
                  label: Text(l10n.openLibrary),
                ),
              ),
            ],
          );
        }

        return DesktopScrollBody(
          padding: padding,
          onRefresh: () => _refresh(ref),
          children: [
            DesktopPageHeader(
              title: l10n.downloadsPageTitle,
              subtitle: l10n.offlineBooksSaved(offlineBooks.length),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _confirmClearAll(context, ref, l10n),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(l10n.downloadsClearAllCache),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (activeJobs.isNotEmpty) ...[
              const SizedBox(height: 24),
              DesktopSection(
                title: l10n.downloadsActiveSection.toUpperCase(),
                child: DesktopPanel(
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
              const SizedBox(height: 20),
              DesktopSection(
                title: l10n.downloadsFailedSection.toUpperCase(),
                child: DesktopPanel(
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
              const SizedBox(height: 20),
              DesktopSection(
                title: l10n.downloadsSavedSection.toUpperCase(),
                child: DesktopPanel(
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
        );
      },
      loading: () => DesktopScrollBody(
        padding: padding,
        children: [
          DesktopPageHeader(
            title: l10n.downloadsPageTitle,
            subtitle: l10n.downloadsEmptyMessage,
          ),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      error: (e, _) => DesktopScrollBody(
        padding: padding,
        children: [
          DesktopPageHeader(title: l10n.downloadsPageTitle),
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
    final matches =
        catalog?.items.where((b) => b.id == job.bookId).toList() ?? [];
    final title = matches.isNotEmpty ? matches.first.title : job.bookId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(failed ? Icons.error_outline : Icons.downloading, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
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
              width: 18,
              height: 18,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (entry.authorCompiler?.isNotEmpty == true)
                  Text(
                    entry.authorCompiler!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
        ],
      ),
    );
  }
}
