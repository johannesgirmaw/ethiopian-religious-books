import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_decorations.dart';
import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../models/download_job.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/download_jobs_provider.dart';
import '../../router/app_navigation.dart';
import '../../utils/catalog_language_label.dart';
import '../../utils/offline_book_download.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/book_reviews_section.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/primitives/shell_primitives.dart';
import '../../widgets/reference/book_detail_cover.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/stored_rich_text_view.dart';
import '../design/web_tokens.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/common/web_metric_row.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

class BookDetailBody extends ConsumerWidget {
  const BookDetailBody({
    super.key,
    required this.bookId,
    required this.onShare,
  });

  final String bookId;
  final void Function(BookSummary book) onShare;

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

  String _statValue(int? value) => value == null ? '—' : '$value';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final contentAsync = ref.watch(bookContentProvider(bookId));
    final downloadJobs = ref.watch(downloadJobsProvider);
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));
    final tier = AppLayoutScope.tierOf(context);

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

    return asyncBook.when(
      data: (book) {
        final tree = contentAsync.valueOrNull;
        final chapterCount = tree?.chapters.length;
        final pageCount = tree?.totalPages;

        return ListView(
          padding: padding,
          children: [
            WebPageHeader(
              title: book.title,
              subtitle: [
                if (book.authorCompiler?.isNotEmpty == true) book.authorCompiler!,
                if (book.subtitle?.isNotEmpty == true) book.subtitle!,
              ].join(' · '),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: tier == AppLayoutTier.expanded ? 240 : 160,
                  child: BookDetailCover(book: book),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: _BookMetadataColumn(
                    book: book,
                    l10n: l10n,
                    onShare: () => onShare(book),
                    onDownload: () => _downloadSample(context, ref),
                    onRead: () async {
                      if (await ensureBookUnlocked(context, book) &&
                          context.mounted) {
                        context.push('/reader/$bookId?pickChapter=1');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            WebMetricRow(
              children: [
                _BookDetailStatCard(
                  icon: Icons.menu_book_outlined,
                  value: _statValue(chapterCount),
                  label: l10n.bookStatChapters,
                ),
                _BookDetailStatCard(
                  icon: Icons.description_outlined,
                  value: _statValue(
                    pageCount != null && pageCount > 0 ? pageCount : null,
                  ),
                  label: l10n.bookStatPages,
                ),
                _BookDetailStatCard(
                  icon: Icons.groups_outlined,
                  value: '—',
                  label: l10n.bookStatReaders,
                ),
              ],
            ),
            const SizedBox(height: 28),
            WebSection(
              title: l10n.summarySection.toUpperCase(),
              child: WebPanel(
                child: book.summary != null && book.summary!.isNotEmpty
                    ? StoredRichTextView(
                        raw: book.summaryRichRaw ?? book.summary!,
                      )
                    : Text(
                        l10n.noSummaryYet,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
              ),
            ),
            if (currentJob != null) ...[
              const SizedBox(height: 16),
              _DownloadStatusCard(job: currentJob),
            ],
            const SizedBox(height: 28),
            BookReviewsSection(bookId: bookId),
          ],
        );
      },
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
    );
  }
}

class _BookMetadataColumn extends StatelessWidget {
  const _BookMetadataColumn({
    required this.book,
    required this.l10n,
    required this.onShare,
    required this.onDownload,
    required this.onRead,
  });

  final BookSummary book;
  final AppLocalizations l10n;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LanguagePill(
          label: catalogLanguageFilterLabel(book.primaryLanguage, l10n),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onRead,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.referencePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: Text(l10n.readNow),
            ),
            OutlinedButton.icon(
              onPressed: onDownload,
              style: OutlinedButton.styleFrom(
                backgroundColor: WebTokens.surfaceBg,
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: WebTokens.borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_outlined, size: 20),
              label: Text(l10n.downloadOffline),
            ),
            IconButton.outlined(
              onPressed: onShare,
              tooltip: l10n.shareBookTooltip,
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.referencePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.referencePrimary,
        ),
      ),
    );
  }
}

class _BookDetailStatCard extends StatelessWidget {
  const _BookDetailStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: WebTokens.panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.referencePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.referencePrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
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
