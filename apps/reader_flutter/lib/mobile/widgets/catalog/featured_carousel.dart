import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../models/book_models.dart';
import 'featured_book_card.dart';

/// Swipeable "Popular" banner — a carousel of [FeaturedBookCard]s with a peek
/// of the next card and page-indicator dots, matching the reference home.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.books});

  final List<BookSummary> books;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    if (books.isEmpty) return const SizedBox.shrink();
    if (books.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.pageHorizontal,
        ),
        child: FeaturedBookCard(book: books.first, index: 0),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 192,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: books.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FeaturedBookCard(book: books[i], index: i),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < books.length; i++)
              AnimatedContainer(
                duration: AppMotion.short,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
