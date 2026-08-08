import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../providers/catalog_providers.dart';
import '../../../widgets/cover_badges.dart';
import '../../../widgets/favourite_heart_button.dart';
import 'book_cover_poster.dart';

/// Poster-style book card matching the reference: tall gradient cover with a
/// "READ NOW" pill and favourite heart, then title + author beneath.
class MobileBookCard extends ConsumerWidget {
  const MobileBookCard({
    super.key,
    required this.book,
    required this.index,
    this.width,
    this.coverAspectRatio = 0.78,
  });

  final BookSummary book;
  final int index;

  /// When set, the card is fixed-width (for horizontal rails). Null = fill
  /// (for grids).
  final double? width;
  final double coverAspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final meta = ref.watch(catalogBookMetaProvider(book.id)).valueOrNull;
    final progress = (meta?.progress ?? 0).clamp(0.0, 1.0);
    final author = book.authorCompiler?.trim();

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: coverAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BookCoverPoster(book: book, index: index),
              Positioned(
                top: 8,
                left: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (book.hasRating) ...[
                      RatingBadge(average: book.ratingAverage),
                      const SizedBox(height: 5),
                    ],
                    ReadNowBadge(label: l10n.readNow),
                    if (book.isPremium) ...[
                      const SizedBox(height: 5),
                      const PremiumBadge(),
                    ],
                    if (book.requiresPurchase) ...[
                      const SizedBox(height: 5),
                      PriceBadge(book: book),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: FavouriteHeartButton(bookId: book.id),
              ),
              if (progress > 0)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.30),
                      color: AppColors.accent,
                    ),
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
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (author != null && author.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'by $author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );

    final tappable = GestureDetector(
      onTap: () => context.push(
        book.isBible ? '/bible/book/${book.id}' : '/book/${book.id}',
      ),
      behavior: HitTestBehavior.opaque,
      child: card,
    );

    if (width == null) return tappable;
    return SizedBox(width: width, child: tappable);
  }
}

/// Row-style book entry for the mobile catalog list view.
class MobileBookListRow extends ConsumerWidget {
  const MobileBookListRow({
    super.key,
    required this.book,
    required this.index,
  });

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(catalogBookMetaProvider(book.id)).valueOrNull;
    final progress = (meta?.progress ?? 0).clamp(0.0, 1.0);
    final author = book.authorCompiler?.trim();

    return GestureDetector(
      onTap: () => context.push(
        book.isBible ? '/bible/book/${book.id}' : '/book/${book.id}',
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: BookCoverPoster(book: book, index: index),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (author != null && author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'by $author',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  if (progress > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppColors.line,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            FavouriteHeartButton(bookId: book.id, size: 28),
          ],
        ),
      ),
    );
  }
}
