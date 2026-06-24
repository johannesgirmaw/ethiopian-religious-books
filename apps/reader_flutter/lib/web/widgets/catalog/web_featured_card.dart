import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../utils/catalog_book_visuals.dart';
import '../../../utils/catalog_categories.dart';
import '../../../widgets/cover_badges.dart';
import '../../design/web_tokens.dart';
import 'book_tile_hover.dart';

/// Wide "Popular" featured banner for the web home.
class WebFeaturedCard extends StatelessWidget {
  const WebFeaturedCard({
    super.key,
    required this.book,
    required this.index,
  });

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final author = book.authorCompiler?.trim();

    return WebBookTileHover(
      route: '/book/${book.id}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WebTokens.borderColor),
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: catalogBookGradient(index),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.listRow,
                    ),
                    child: Icon(
                      categoryForBook(book).icon,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  if (book.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CoverImageFill(url: book.coverUrl!),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.homePopularBadge,
                          style: const TextStyle(
                            fontSize: 12,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (book.hasRating) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          '${book.ratingAverage.toStringAsFixed(1)} · ${book.ratingCount}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.homeReadMore,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
