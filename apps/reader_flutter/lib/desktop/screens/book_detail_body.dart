import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../widgets/reference/book_detail_cover.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/stored_rich_text_view.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_section.dart';

/// Maximum width of the detail content column on very large displays.
const double _kDetailMaxWidth = 1160;

/// Width of the right-hand "details" aside on medium / expanded tiers.
const double _kAsideWidth = 340;

class DesktopBookDetailBody extends ConsumerWidget {
  const DesktopBookDetailBody({
    super.key,
    required this.bookId,
    required this.onShare,
  });

  final String bookId;
  final void Function(BookSummary book) onShare;

  Future<void> _downloadSample(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.preparingDownload)));
    final error = await runOfflineBookDownload(ref, bookId, l10n: l10n);
    if (!context.mounted) return;
    ref.invalidate(downloadJobsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? l10n.savedOfflineReading)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final contentAsync = ref.watch(bookContentProvider(bookId));
    final downloadJobs = ref.watch(downloadJobsProvider);
    final tier = DesktopLayoutScope.tierOf(context);
    final padding = DesktopTokens.pagePadding(tier);

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
        final twoColumn = tier != DesktopLayoutTier.compact;

        final hero = _HeroCard(
          book: book,
          l10n: l10n,
          tier: tier,
          chapterCount: chapterCount,
          pageCount: pageCount,
          onRead: () => context.push('/reader/$bookId?pickChapter=1'),
          onDownload: () => _downloadSample(context, ref),
          onShare: () => onShare(book),
        );

        final about = _AboutSection(book: book, l10n: l10n);
        final contents = _ContentsSection(
          tree: tree,
          loading: contentAsync.isLoading,
          l10n: l10n,
          onChapter: (key) => context.push('/reader/$bookId?chapter=$key'),
          onReadStart: () => context.push('/reader/$bookId?pickChapter=1'),
        );
        final details = _DetailsCard(
          book: book,
          l10n: l10n,
          chapterCount: chapterCount,
          pageCount: pageCount,
        );

        final Widget body;
        if (twoColumn) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    about,
                    const SizedBox(height: 24),
                    contents,
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: _kAsideWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    if (currentJob != null) ...[
                      const SizedBox(height: 16),
                      _DownloadStatusCard(job: currentJob),
                    ],
                  ],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              about,
              const SizedBox(height: 20),
              contents,
              const SizedBox(height: 20),
              details,
              if (currentJob != null) ...[
                const SizedBox(height: 16),
                _DownloadStatusCard(job: currentJob),
              ],
            ],
          );
        }

        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 28),
                  body,
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
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

/// Polished header band: large cover, title block, quick stats and actions.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.book,
    required this.l10n,
    required this.tier,
    required this.chapterCount,
    required this.pageCount,
    required this.onRead,
    required this.onDownload,
    required this.onShare,
  });

  final BookSummary book;
  final AppLocalizations l10n;
  final DesktopLayoutTier tier;
  final int? chapterCount;
  final int? pageCount;
  final VoidCallback onRead;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final coverWidth = switch (tier) {
      DesktopLayoutTier.expanded => 210.0,
      DesktopLayoutTier.medium => 176.0,
      DesktopLayoutTier.compact => 148.0,
    };
    final titleSize = tier == DesktopLayoutTier.expanded ? 32.0 : 26.0;

    return Container(
      padding: EdgeInsets.all(tier == DesktopLayoutTier.expanded ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              AppColors.referencePrimary.withValues(alpha: 0.09),
              DesktopTokens.surfaceBg,
            ),
            Color.alphaBlend(
              AppColors.referenceAccent.withValues(alpha: 0.05),
              DesktopTokens.surfaceBg,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesktopTokens.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.referencePrimary.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: BookDetailCover(book: book, width: coverWidth),
          ),
          SizedBox(width: tier == DesktopLayoutTier.expanded ? 32 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguagePill(
                  label: catalogLanguageFilterLabel(book.primaryLanguage, l10n),
                ),
                const SizedBox(height: 14),
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (book.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    book.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (book.authorCompiler?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          book.authorCompiler!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaChip(
                      icon: Icons.menu_book_outlined,
                      value: chapterCount == null ? '—' : '$chapterCount',
                      label: l10n.bookStatChapters,
                    ),
                    _MetaChip(
                      icon: Icons.description_outlined,
                      value: (pageCount != null && pageCount! > 0)
                          ? '$pageCount'
                          : '—',
                      label: l10n.bookStatPages,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRead,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.referencePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.auto_stories_rounded, size: 19),
                      label: Text(l10n.startReading),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDownload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: DesktopTokens.borderColor),
                        backgroundColor: DesktopTokens.surfaceBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.downloadOffline),
                    ),
                    IconButton.outlined(
                      onPressed: onShare,
                      tooltip: l10n.shareBookTooltip,
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: DesktopTokens.borderColor),
                        backgroundColor: DesktopTokens.surfaceBg,
                        padding: const EdgeInsets.all(13),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.book, required this.l10n});

  final BookSummary book;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final hasSummary = book.summary?.isNotEmpty == true;
    return DesktopSection(
      title: l10n.summarySection.toUpperCase(),
      child: DesktopPanel(
        padding: const EdgeInsets.all(20),
        child: hasSummary
            ? StoredRichTextView(raw: book.summaryRichRaw ?? book.summary!)
            : Text(
                l10n.noSummaryYet,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
      ),
    );
  }
}

/// Table of contents built from the book's chapter tree.
class _ContentsSection extends StatelessWidget {
  const _ContentsSection({
    required this.tree,
    required this.loading,
    required this.l10n,
    required this.onChapter,
    required this.onReadStart,
  });

  final BookContentTree? tree;
  final bool loading;
  final AppLocalizations l10n;
  final void Function(String chapterKey) onChapter;
  final VoidCallback onReadStart;

  @override
  Widget build(BuildContext context) {
    final chapters = tree?.chapters ?? const <BookContentChapter>[];
    return DesktopSection(
      title: l10n.chaptersHeading.toUpperCase(),
      trailing: chapters.isEmpty
          ? null
          : Text(
              '${chapters.length} ${l10n.chaptersHeading}',
              style: DesktopTokens.sectionLabelStyle,
            ),
      child: DesktopPanel(
        padding: EdgeInsets.zero,
        child: loading && chapters.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : chapters.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.noChapterContentYet,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < chapters.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: DesktopTokens.borderColor,
                          ),
                        _TocRow(
                          index: i + 1,
                          chapter: chapters[i],
                          pageLabel: l10n.pageCount(chapters[i].pages.length),
                          onTap: () => onChapter(chapters[i].chapterKey),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.index,
    required this.chapter,
    required this.pageLabel,
    required this.onTap,
  });

  final int index;
  final BookContentChapter chapter;
  final String pageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: DesktopTokens.hoverBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.referencePrimary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.referencePrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              pageLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.book,
    required this.l10n,
    required this.chapterCount,
    required this.pageCount,
  });

  final BookSummary book;
  final AppLocalizations l10n;
  final int? chapterCount;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (
        label: l10n.languagesMetric,
        value: catalogLanguageFilterLabel(book.primaryLanguage, l10n),
      ),
      if (book.authorCompiler?.isNotEmpty == true)
        (label: l10n.authorCompilerLabel, value: book.authorCompiler!),
      if (chapterCount != null)
        (label: l10n.bookStatChapters, value: '$chapterCount'),
      if (pageCount != null && pageCount! > 0)
        (label: l10n.bookStatPages, value: '$pageCount'),
    ];

    return DesktopSection(
      title: l10n.bookDetailsTitle.toUpperCase(),
      child: DesktopPanel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: DesktopTokens.borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rows[i].label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        rows[i].value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small icon + value + label chip used for the hero quick-stats.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesktopTokens.surfaceBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesktopTokens.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.referencePrimary),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.referencePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.referencePrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.translate_rounded,
            size: 13,
            color: AppColors.referencePrimary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.referencePrimary,
            ),
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
        borderRadius: BorderRadius.circular(10),
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
            size: 18,
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
