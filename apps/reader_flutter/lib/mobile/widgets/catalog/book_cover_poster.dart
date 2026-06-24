import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../models/book_models.dart';
import '../../../utils/catalog_book_visuals.dart';
import '../../../utils/catalog_categories.dart';
import '../../../widgets/cover_badges.dart';
export '../../../widgets/cover_badges.dart'
    show ReadNowBadge, CoverHeartButton, RatingBadge, PremiumBadge, CoverImageFill;

/// Gradient "cover" for a book — the app has no cover images, so we render a
/// branded gradient poster with the book's category icon and a faint cross
/// watermark. Shared by grid cards, featured cards, and continue-reading.
class BookCoverPoster extends StatelessWidget {
  const BookCoverPoster({
    super.key,
    required this.book,
    required this.index,
    this.borderRadius = AppRadius.md,
    this.iconSize = 30,
    this.showTitle = true,
  });

  final BookSummary book;
  final int index;
  final double borderRadius;
  final double iconSize;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final category = categoryForBook(book);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: catalogBookGradient(index),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.listRow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CatalogCrossWatermark(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: iconSize + 8,
                    height: iconSize + 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: iconSize * 0.62,
                    ),
                  ),
                  const Spacer(),
                  if (showTitle)
                    Text(
                      book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            if (book.coverUrl != null)
              Positioned.fill(child: CoverImageFill(url: book.coverUrl!)),
          ],
        ),
      ),
    );
  }
}

