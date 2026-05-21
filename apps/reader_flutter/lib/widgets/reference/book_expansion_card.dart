import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import 'content_list_item.dart';

/// Expandable book card; expanding shows chapter list (tap chapter to read).
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

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            iconColor: Colors.grey[600],
            collapsedIconColor: Colors.grey[600],
            onExpansionChanged: (open) => setState(() => _expanded = open),
            title: Row(
              children: [
                if (widget.index != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.referencePrimary.withValues(alpha: 0.8),
                          AppColors.referencePrimary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.index! + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (book.authorCompiler?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.authorCompiler!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
    final sorted = [...chapters]..sort((a, b) => a.ordinal.compareTo(b.ordinal));

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

  void _openChapter(BuildContext context, String bookId, BookContentChapter chapter) {
    final firstPage = chapter.pages.isNotEmpty
        ? chapter.pages.first.pageNumber
        : null;
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
        final sorted = [...chapters]..sort((a, b) => a.ordinal.compareTo(b.ordinal));
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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
    return ContentListItem(
      title: title,
      onTap: onTap,
    );
  }
}
