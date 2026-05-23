import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import 'content_list_item.dart';

/// Expandable book card — premium design with colored index badge.
class BookExpansionCard extends ConsumerStatefulWidget {
  const BookExpansionCard({
    super.key,
    required this.book,
    this.index,
  });

  final BookSummary book;
  final int? index;

  @override
  ConsumerState<BookExpansionCard> createState() => _BookExpansionCardState();
}

class _BookExpansionCardState extends ConsumerState<BookExpansionCard> {
  bool _expanded = false;

  // Pick a gradient stop based on index for variety
  LinearGradient _badgeGradient(int index) {
    const gradients = [
      LinearGradient(
        colors: [Color(0xFF5B3B8C), Color(0xFF3B2460)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFC1272D), Color(0xFF8B1A1A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFE8B84B), Color(0xFFD4A017)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final idx = widget.index ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            backgroundColor: AppColors.surfaceCard,
            collapsedBackgroundColor: AppColors.surfaceCard,
            iconColor: AppColors.textTertiary,
            collapsedIconColor: AppColors.textTertiary,
            onExpansionChanged: (open) =>
                setState(() => _expanded = open),
            leading: Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                gradient: _badgeGradient(idx),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Center(
                child: Text(
                  '${idx + 1}',
                  style: TextStyle(
                    color: idx % 2 == 2
                        ? AppColors.primaryDeep
                        : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            title: Text(
              book.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            subtitle: book.authorCompiler?.isNotEmpty == true
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      book.authorCompiler!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: AppColors.border),
                ),
                child: _expanded
                    ? _ChapterList(bookId: book.id)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterList extends ConsumerWidget {
  const _ChapterList({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(bookContentProvider(bookId));

    return contentAsync.when(
      data: (tree) {
        if (tree.chapters.isNotEmpty) {
          return _ContentChapterList(
            bookId: bookId,
            chapters: tree.chapters,
          );
        }
        return _ApiChapterListFallback(bookId: bookId);
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
      error: (_, __) => _ApiChapterListFallback(bookId: bookId),
    );
  }
}

class _ContentChapterList extends StatelessWidget {
  const _ContentChapterList({
    required this.bookId,
    required this.chapters,
  });

  final String bookId;
  final List<BookContentChapter> chapters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...chapters]
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));

    return Column(
      children: sorted.map((chapter) {
        final title = chapter.title.trim().isNotEmpty
            ? chapter.title.trim()
            : chapter.chapterKey;
        final pageCount = chapter.pages.length;
        return ContentListItem(
          title: title,
          subtitle: pageCount > 0 ? l10n.pageCount(pageCount) : null,
          onTap: () => _openChapter(context, bookId, chapter),
        );
      }).toList(),
    );
  }

  void _openChapter(
      BuildContext context, String bookId, BookContentChapter chapter) {
    final firstPage =
        chapter.pages.isNotEmpty ? chapter.pages.first.pageNumber : null;
    final uri = Uri(
      path: '/reader/$bookId',
      queryParameters: {
        'chapter': chapter.chapterKey,
        if (firstPage != null) 'page': '$firstPage',
      },
    );
    context.push(uri.toString());
  }
}

class _ApiChapterListFallback extends ConsumerWidget {
  const _ApiChapterListFallback({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(bookChaptersProvider(bookId));

    return async.when(
      data: (chapters) {
        if (chapters.isEmpty) {
          return _EmptyChaptersMessage(
            title: l10n.readFullBook,
            onTap: () => context.push('/reader/$bookId'),
          );
        }
        final sorted = [...chapters]
          ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
        return Column(
          children: sorted.map((ch) {
            final title =
                ch.title.trim().isNotEmpty ? ch.title.trim() : ch.chapterKey;
            return ContentListItem(
              title: title,
              onTap: () => context.push(
                '/reader/$bookId?chapter=${Uri.encodeComponent(ch.chapterKey)}',
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
      error: (_, __) => _EmptyChaptersMessage(
        title: l10n.readFullBook,
        onTap: () => context.push('/reader/$bookId'),
      ),
    );
  }
}

class _EmptyChaptersMessage extends StatelessWidget {
  const _EmptyChaptersMessage({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ContentListItem(title: title, onTap: onTap);
  }
}
