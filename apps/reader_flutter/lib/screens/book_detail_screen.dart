import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../models/download_job.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/download_jobs_storage.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/stored_rich_text_view.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  Future<void> _downloadSample(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.preparingDownload)));
    await DownloadJobsStorage.upsertJob(
      DownloadJob(
        bookId: bookId,
        state: 'in_progress',
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    try {
      final payload = await ref.read(downloadInfoProvider(bookId).future);
      final dir = await getApplicationDocumentsDirectory();
      final bookDir =
          Directory('${dir.path}/books/$bookId/${payload.revisionId}');
      await bookDir.create(recursive: true);
      final manifestPath = '${bookDir.path}/manifest.json';
      final plain = Dio();
      await plain.download(payload.manifestUrl, manifestPath);
      for (final part in payload.packageParts) {
        final name = 'part_${part.partIndex}.bin';
        await plain.download(part.url, '${bookDir.path}/$name');
      }
      if (!context.mounted) return;
      await DownloadJobsStorage.upsertJob(
        DownloadJob(
          bookId: bookId,
          state: 'completed',
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedUnderPath(bookDir.path))),
      );
    } catch (e) {
      if (!context.mounted) return;
      await DownloadJobsStorage.upsertJob(
        DownloadJob(
          bookId: bookId,
          state: 'failed',
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          errorMessage: '$e',
        ),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final downloadJobs = ref.watch(downloadJobsProvider);
    DownloadJob? currentJob;
    final jobs = downloadJobs.valueOrNull;
    if (jobs != null) {
      for (final job in jobs.reversed) {
        if (job.bookId == bookId) {
          currentJob = job;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.bookDetailsTitle),
      ),
      body: asyncBook.when(
        data: (book) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Hero header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.surfaceCard,
                    AppColors.surfaceSoft,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      book.primaryLanguage ?? l10n.generalCategory,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (book.subtitle != null && book.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      book.subtitle!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                  if (book.authorCompiler != null &&
                      book.authorCompiler!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            book.authorCompiler!,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Summary section
            if (book.summary != null && book.summary!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.summarySection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: StoredRichTextView(
                    raw: book.summaryRichRaw ?? book.summary!),
              ),
            ],
            // Actions section
            const SizedBox(height: 24),
            Text(
              l10n.readyToRead,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            if (currentJob != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: currentJob.state == 'completed'
                      ? Colors.green.shade50
                      : currentJob.state == 'failed'
                          ? Colors.red.shade50
                          : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: currentJob.state == 'completed'
                        ? Colors.green.shade200
                        : currentJob.state == 'failed'
                            ? Colors.red.shade200
                            : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentJob.state == 'completed'
                          ? Icons.check_circle_outline_rounded
                          : currentJob.state == 'failed'
                              ? Icons.error_outline_rounded
                              : Icons.downloading_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.downloadState(currentJob.state),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (currentJob.errorMessage != null)
                            Text(
                              currentJob.errorMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: () => context.push('/reader/$bookId'),
              icon: const Icon(Icons.chrome_reader_mode_rounded),
              label: Text(l10n.startReading),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _downloadSample(context, ref),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.downloadOffline),
            ),
          ],
        ),
        loading: () => const SkeletonCardGroup(count: 4),
        error: (e, _) {
          String title = l10n.unableToLoadBook;
          String message = l10n.bookLoadErrorMessage;
          if (e is DioException && e.response?.statusCode == 404) {
            title = l10n.bookNotInCatalogTitle;
            message = l10n.bookNotInCatalogMessage;
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.goBack),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
