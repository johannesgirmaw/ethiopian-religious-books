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
import '../../providers/payment_providers.dart';
import '../../router/app_navigation.dart';
import '../../utils/catalog_categories.dart';
import '../../utils/catalog_language_label.dart';
import '../../utils/offline_book_download.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/book_reviews_section.dart';
import '../../widgets/cover_badges.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/reference/book_detail_cover.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/stored_rich_text_view.dart';
import '../design/web_tokens.dart';
import '../layout/app_layout_scope.dart';
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
    final l10n = AppLocalizations.of(context);
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
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final contentAsync = ref.watch(bookContentProvider(bookId));
    final downloadJobs = ref.watch(downloadJobsProvider);
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));
    final tier = AppLayoutScope.tierOf(context);
    final expanded = tier == AppLayoutTier.expanded;

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
        final mustBuy = book.requiresPurchase &&
            !(ref
                    .watch(entitledBookIdsProvider)
                    .valueOrNull
                    ?.contains(bookId) ??
                false);

        Future<void> onRead() async {
          if (await ensureBookUnlocked(context, ref, book) &&
              context.mounted) {
            context.push(
              readingPathForBook(
                bookId,
                isPdf: book.isPdf,
                query: 'pickChapter=1',
              ),
            );
          }
        }

        final actions = _ActionCluster(
          l10n: l10n,
          mustBuy: mustBuy,
          stretch: expanded,
          onRead: onRead,
          onDownload: () => _downloadSample(context, ref),
          onShare: () => onShare(book),
        );

        final header = _TitleBlock(
          book: book,
          l10n: l10n,
          chapterCount: chapterCount,
          pageCount: pageCount,
          large: expanded,
        );

        final about = _AboutSection(book: book, l10n: l10n);
        final contents = book.isPdf
            ? WebSection(
                title: l10n.pdfDocumentSection.toUpperCase(),
                child: WebPanel(
                  child: Text(
                    l10n.pdfNoChaptersHint,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              )
            : _ContentsSection(
                tree: tree,
                loading: contentAsync.isLoading,
                l10n: l10n,
                onChapter: (key) => context.push(
                  readingPathForBook(
                    bookId,
                    isPdf: false,
                    query: 'chapter=$key',
                  ),
                ),
              );

        final sections = <Widget>[
          about,
          const SizedBox(height: 28),
          contents,
          if (currentJob != null && !expanded) ...[
            const SizedBox(height: 16),
            _DownloadStatusCard(job: currentJob),
          ],
          const SizedBox(height: 32),
          BookReviewsSection(bookId: bookId),
        ];

        if (expanded) {
          return ListView(
            padding: padding,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: WebTokens.bookDetailRailWidth,
                    child: _CoverRail(
                      book: book,
                      l10n: l10n,
                      chapterCount: chapterCount,
                      pageCount: pageCount,
                      downloadJob: currentJob,
                      actions: actions,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 32),
                        ...sections,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return ListView(
          padding: padding,
          children: [
            _HeroRow(
              book: book,
              header: header,
              actions: actions,
            ),
            if (currentJob != null) ...[
              const SizedBox(height: 16),
              _DownloadStatusCard(job: currentJob),
            ],
            const SizedBox(height: 32),
            ...sections,
          ],
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

class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.book,
    required this.header,
    required this.actions,
  });

  final BookSummary book;
  final Widget header;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: WebTokens.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 28, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverFrame(
              book: book,
              width: WebTokens.bookDetailCoverMedium,
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 22),
                  actions,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverRail extends StatelessWidget {
  const _CoverRail({
    required this.book,
    required this.l10n,
    required this.chapterCount,
    required this.pageCount,
    required this.downloadJob,
    required this.actions,
  });

  final BookSummary book;
  final AppLocalizations l10n;
  final int? chapterCount;
  final int? pageCount;
  final DownloadJob? downloadJob;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _CoverFrame(
            book: book,
            width: WebTokens.bookDetailCoverExpanded,
          ),
        ),
        const SizedBox(height: 24),
        actions,
        if (downloadJob != null) ...[
          const SizedBox(height: 14),
          _DownloadStatusCard(job: downloadJob!),
        ],
        const SizedBox(height: 28),
        _DetailsCard(
          book: book,
          l10n: l10n,
          chapterCount: chapterCount,
          pageCount: pageCount,
        ),
      ],
    );
  }
}

class _CoverFrame extends StatelessWidget {
  const _CoverFrame({
    required this.book,
    required this.width,
  });

  final BookSummary book;
  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: WebTokens.coverShadow,
      ),
      child: BookDetailCover(
        book: book,
        width: width,
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.book,
    required this.l10n,
    required this.chapterCount,
    required this.pageCount,
    required this.large,
  });

  final BookSummary book;
  final AppLocalizations l10n;
  final int? chapterCount;
  final int? pageCount;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final category = categoryForBook(book);
    final titleSize = large ? 34.0 : 26.0;
    final pageValue =
        pageCount != null && pageCount! > 0 ? '$pageCount' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LanguagePill(
              label: catalogLanguageFilterLabel(book.primaryLanguage, l10n),
            ),
            if (category != BookCategory.other)
              _SoftPill(label: category.label(l10n)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          book.title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.7,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [AppColors.referencePrimary, Color(0xFFF5A623)],
            ),
          ),
        ),
        if (book.subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            book.subtitle!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (book.authorCompiler?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _AuthorLink(name: book.authorCompiler!, l10n: l10n),
        ],
        if (book.hasRating) ...[
          const SizedBox(height: 12),
          _RatingRow(book: book),
        ],
        if (book.requiresPurchase) ...[
          const SizedBox(height: 14),
          BookPriceLabel(book: book),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (chapterCount != null)
              _MetaChip(
                icon: Icons.menu_book_outlined,
                value: '$chapterCount',
                label: l10n.bookStatChapters,
              ),
            if (pageValue != null)
              _MetaChip(
                icon: Icons.description_outlined,
                value: pageValue,
                label: l10n.bookStatPages,
              ),
            if (book.readersCount > 0)
              _MetaChip(
                icon: Icons.groups_outlined,
                value: '${book.readersCount}',
                label: l10n.bookStatReaders,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionCluster extends StatelessWidget {
  const _ActionCluster({
    required this.l10n,
    required this.mustBuy,
    required this.stretch,
    required this.onRead,
    required this.onDownload,
    required this.onShare,
  });

  final AppLocalizations l10n;
  final bool mustBuy;
  final bool stretch;
  final VoidCallback onRead;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      onPressed: onRead,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.referencePrimary,
        foregroundColor: Colors.white,
        minimumSize: stretch ? const Size.fromHeight(48) : const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      icon: Icon(
        mustBuy ? Icons.shopping_cart_outlined : Icons.auto_stories_rounded,
        size: 19,
      ),
      label: Text(mustBuy ? l10n.purchaseBook : l10n.readNow),
    );

    final download = OutlinedButton.icon(
      onPressed: onDownload,
      style: OutlinedButton.styleFrom(
        backgroundColor: WebTokens.surfaceBg,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: WebTokens.borderColor),
        minimumSize: stretch ? const Size.fromHeight(46) : const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      icon: const Icon(Icons.download_outlined, size: 18),
      label: Text(l10n.downloadOfflineShort),
    );

    final share = IconButton.outlined(
      onPressed: onShare,
      tooltip: l10n.shareBookTooltip,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: WebTokens.borderColor),
        backgroundColor: WebTokens.surfaceBg,
        minimumSize: const Size(46, 46),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      icon: const Icon(Icons.share_outlined, size: 18),
    );

    if (stretch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: download),
              const SizedBox(width: 10),
              share,
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [primary, download, share],
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
    return WebSection(
      title: l10n.summarySection.toUpperCase(),
      child: hasSummary
          ? WebPanel(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: StoredRichTextView(
                raw: book.summaryRichRaw ?? book.summary!,
              ),
            )
          : _QuietEmpty(
              icon: Icons.notes_outlined,
              message: l10n.noSummaryYet,
            ),
    );
  }
}

class _ContentsSection extends StatelessWidget {
  const _ContentsSection({
    required this.tree,
    required this.loading,
    required this.l10n,
    required this.onChapter,
  });

  final BookContentTree? tree;
  final bool loading;
  final AppLocalizations l10n;
  final void Function(String chapterKey) onChapter;

  @override
  Widget build(BuildContext context) {
    final chapters = tree?.chapters ?? const <BookContentChapter>[];
    return WebSection(
      title: l10n.chaptersHeading.toUpperCase(),
      trailing: chapters.isEmpty
          ? null
          : Text(
              '${chapters.length}',
              style: WebTokens.sectionLabelStyle,
            ),
      child: loading && chapters.isEmpty
          ? const WebPanel(
              child: Center(child: CircularProgressIndicator()),
            )
          : chapters.isEmpty
              ? _QuietEmpty(
                  icon: Icons.menu_book_outlined,
                  message: l10n.noChapterContentYet,
                )
              : WebPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < chapters.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: WebTokens.borderColor,
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

class _TocRow extends StatefulWidget {
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
  State<_TocRow> createState() => _TocRowState();
}

class _TocRowState extends State<_TocRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: _hovered
            ? AppColors.referencePrimary.withValues(alpha: 0.05)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.referencePrimary.withValues(
                      alpha: _hovered ? 0.16 : 0.09,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${widget.index}',
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
                    widget.chapter.title,
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
                  widget.pageLabel,
                  style: WebTokens.sectionLabelStyle.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _hovered
                      ? AppColors.referencePrimary
                      : AppColors.textTertiary,
                ),
              ],
            ),
          ),
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
    final displayRows = <({String label, String value})>[
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

    return WebSection(
      title: l10n.bookDetailsTitle.toUpperCase(),
      child: WebPanel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < displayRows.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: WebTokens.borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayRows[i].label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        displayRows[i].value,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WebTokens.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.referencePrimary),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.referencePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.referencePrimary.withValues(alpha: 0.16),
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
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.referencePrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WebTokens.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: WebTokens.borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final filled = book.ratingAverage.round().clamp(0, 5);
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: AppColors.accent,
          ),
        const SizedBox(width: 8),
        Text(
          book.ratingAverage.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '·  ${book.ratingCount}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _AuthorLink extends StatelessWidget {
  const _AuthorLink({required this.name, required this.l10n});

  final String name;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: () =>
            context.push('/author/${Uri.encodeComponent(name.trim())}'),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.authoredBy(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.referencePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.referencePrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
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
    final l10n = AppLocalizations.of(context);
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
        borderRadius: BorderRadius.circular(12),
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
