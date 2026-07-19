import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import 'book_cover_poster.dart';

/// The "Popular" featured banner at the top of the home screen.
class FeaturedBookCard extends StatelessWidget {
  const FeaturedBookCard({super.key, required this.book, required this.index});

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final author = book.authorCompiler?.trim();

    return GestureDetector(
      onTap: () => context.push(
        book.isBible ? '/bible/book/${book.id}' : '/book/${book.id}',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppShadows.listRow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.homePopularBadge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (author != null && author.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      book.publishedYear != null
                          ? '$author (${book.publishedYear})'
                          : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (book.hasRating) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${book.ratingAverage.toStringAsFixed(1)} · ${book.ratingCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.homeReadMore,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 96,
              height: 124,
              child: BookCoverPoster(
                book: book,
                index: index,
                borderRadius: AppRadius.md,
                iconSize: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
