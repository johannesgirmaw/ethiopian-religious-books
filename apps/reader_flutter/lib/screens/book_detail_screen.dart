import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../router/app_navigation.dart';
import '../l10n/app_localizations.dart';
import '../models/download_job.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../utils/offline_book_download.dart';
import '../widgets/primitives/shared_widgets.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/app_state_view.dart';
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
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.preparingDownload)),
    );
    final error = await runOfflineBookDownload(ref, bookId, l10n: l10n);
    if (!context.mounted) return;
    ref.invalidate(downloadJobsProvider);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedOfflineReading)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOverlayRoute(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOverlayRoute(context),
        ),
        title: Text(l10n.bookDetailsTitle),
        backgroundColor: AppColors.referencePageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: asyncBook.when(
        data: (book) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Center(
                    child: AppBookCover(
                      size: 120,
                      borderRadius: 16,
                      icon: Icons.auto_stories_rounded,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppStatusChip(
                    label: book.primaryLanguage ?? l10n.generalCategory,
                    kind: AppStatusKind.accent,
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
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (book.summary != null && book.summary!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AppSectionAccent(label: l10n.summarySection),
                    const SizedBox(height: 10),
                    AppPanel(
                      child: StoredRichTextView(
                        raw: book.summaryRichRaw ?? book.summary!,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppSectionAccent(label: l10n.readyToRead),
                  const SizedBox(height: 10),
                  if (currentJob != null)
                    _DownloadStatusCard(job: currentJob),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _downloadSample(context, ref),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.downloadOffline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/reader/$bookId?pickChapter=1'),
                icon: const Icon(Icons.chrome_reader_mode_rounded, size: 20),
                label: Text(l10n.readNow),
              ),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonCardGroup(count: 4),
        ),
        error: (e, _) {
          var title = l10n.unableToLoadBook;
          var message = l10n.bookLoadErrorMessage;
          if (e is DioException && e.response?.statusCode == 404) {
            title = l10n.bookNotInCatalogTitle;
            message = l10n.bookNotInCatalogMessage;
          }
          return AppStateView(
            title: title,
            message: message,
            icon: Icons.menu_book_outlined,
            actionLabel: l10n.goBack,
            onAction: () => popOverlayRoute(context),
          );
        },
      ),
    ),
    );
  }
}

class _DownloadStatusCard extends StatelessWidget {
  const _DownloadStatusCard({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOk = job.state == 'completed';
    final isFail = job.state == 'failed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isOk
            ? AppColors.successSurface
            : isFail
                ? AppColors.errorSurface
                : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isOk
              ? AppColors.successBorder
              : isFail
                  ? AppColors.errorBorder
                  : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk
                ? Icons.check_circle_outline_rounded
                : isFail
                    ? Icons.error_outline_rounded
                    : Icons.downloading_rounded,
            size: 20,
            color: isOk
                ? AppColors.successText
                : isFail
                    ? AppColors.errorText
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.state == 'failed'
                  ? displayDownloadJobError(job.errorMessage, l10n)
                  : (job.errorMessage ?? job.state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
