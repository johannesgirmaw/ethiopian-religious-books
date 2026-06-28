import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../models/book_models.dart';
import '../../utils/catalog_book_visuals.dart';
import '../cover_badges.dart';

class BookDetailCover extends StatelessWidget {
  const BookDetailCover({
    super.key,
    required this.book,
    this.width = 108,
    this.expand = false,
  });

  final BookSummary book;
  final double width;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final icon = catalogBookIcon(book, 0);
    final height = width * 1.38;

    return SizedBox(
      width: expand?double.infinity:width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: catalogBookGradient(0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.listRow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              const CatalogCrossWatermark(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const Spacer(),
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
      ),
    );
  }
}
