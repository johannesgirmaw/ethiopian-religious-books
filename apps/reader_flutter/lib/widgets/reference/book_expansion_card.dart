import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import '../primitives/shell_primitives.dart';
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

  static const _accents = [
    AppColors.referencePrimary,
    AppColors.referenceSecondary,
    AppColors.referenceAccent,
    Color(0xFF2D6A4F),
  ];

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final idx = widget.index ?? 0;
    final accent = _accents[idx % _accents.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        boxShadow: AppShadows.listRow,
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
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
            leading: AppBookCover(
              size: 52,
              borderRadius: 12,
              accent: accent,
              icon: Icons.menu_book_rounded,
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
