import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/download_job.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/download_jobs_storage.dart';
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
        SnackBar(content: Text(l10n.preparingDownload)));
    await DownloadJobsStorage.upsertJob(
      DownloadJob(
        bookId: bookId,
        state: 'in_progress',
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    try {
      final payload =
          await ref.read(downloadInfoProvider(bookId).future);
      final dir = await getApplicationDocumentsDirectory();
      final bookDir = Directory(
          '${dir.path}/books/$bookId/${payload.revisionId}');
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
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.downloadFailed('$e'))));
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
      backgroundColor: AppColors.referencePageBg,
      body: asyncBook.when(
        data: (book) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Immersive collapsible hero ──────────────────────
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: AppColors.primaryDeep,
                  leading: IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  title: Text(
                    l10n.bookDetailsTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Gradient background
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradients.hero,
                          ),
                        ),
                        // Decorative circles
                        Positioned(
                          top: -30,
                          right: -40,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        // Book cover placeholder centered
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 100,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    AppRadius.sm),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.22),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.30),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Gold accent bar at bottom of hero
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.accent,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Content ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 24, 20, 120),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Language chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppGradients.hero,
                            borderRadius: BorderRadius.circular(
                                AppRadius.pill),
                          ),
                          child: Text(
                            book.primaryLanguage ??
                                l10n.generalCategory,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          book.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),

                        // Subtitle
                        if (book.subtitle != null &&
                            book.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            book.subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],

                        // Author
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
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Summary
                        if (book.summary != null &&
                            book.summary!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _SectionHeading(
                              label: l10n.summarySection),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                  AppRadius.md),
                              border: Border.all(
                                  color: AppColors.border),
                              boxShadow: AppShadows.card,
                            ),
                            child: StoredRichTextView(
                              raw: book.summaryRichRaw ??
                                  book.summary!,
                            ),
                          ),
                        ],

                        // Download status
                        const SizedBox(height: 24),
                        _SectionHeading(label: l10n.readyToRead),
                        const SizedBox(height: 12),
                        if (currentJob != null)
                          _DownloadStatusCard(job: currentJob),
                        const SizedBox(height: 10),
                        _DownloadButton(
                          onTap: () =>
                              _downloadSample(context, ref),
                          label: l10n.downloadOffline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Sticky "Read Now" CTA
            Positioned(
              left: 20,
              right: 20,
              bottom: 20 + MediaQuery.paddingOf(context).bottom,
              child: _GradientCta(
                label: l10n.readNow,
                onTap: () => context.push('/reader/$bookId'),
              ),
            ),
          ],
        ),
        loading: () => const SkeletonCardGroup(count: 4),
        error: (e, _) {
          String title = l10n.unableToLoadBook;
          String message = l10n.bookLoadErrorMessage;
          if (e is DioException &&
              e.response?.statusCode == 404) {
            title = l10n.bookNotInCatalogTitle;
            message = l10n.bookNotInCatalogMessage;
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppGradients.hero,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  _GradientCta(
                    label: l10n.goBack,
                    onTap: () => context.pop(),
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

// ─── Local widgets ────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppGradients.gold,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _DownloadStatusCard extends StatelessWidget {
  const _DownloadStatusCard({required this.job});
  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final isOk = job.state == 'completed';
    final isFail = job.state == 'failed';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
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
                  : AppColors.border,
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
                ? const Color(0xFF059669)
                : isFail
                    ? const Color(0xFFB91C1C)
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.state,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (job.errorMessage != null)
                  Text(
                    job.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border:
              Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.download_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: AppShadows.floatingBtn,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chrome_reader_mode_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
