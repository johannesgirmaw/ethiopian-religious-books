import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../utils/catalog_book_visuals.dart';
import '../../../utils/catalog_categories.dart';
import '../../../widgets/cover_badges.dart';
import '../../design/desktop_tokens.dart';
import 'book_tile_hover.dart';

/// Wide "Popular" featured banner for the desktop home.
class DesktopFeaturedCard extends StatelessWidget {
  const DesktopFeaturedCard({
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

    return DesktopBookTileHover(
      route: '/book/${book.id}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesktopTokens.borderColor),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 116,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: catalogBookGradient(index),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppShadows.listRow,
                    ),
                    child: Icon(
                      categoryForBook(book).icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  if (book.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CoverImageFill(url: book.coverUrl!),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                  const SizedBox(height: 10),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (author != null && author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.publishedYear != null
                          ? '$author (${book.publishedYear})'
                          : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (book.hasRating) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.accent),
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
                  const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}
