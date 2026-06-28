import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../models/book_models.dart';
import 'web_featured_card.dart';

/// "Popular" featured carousel for the web home.
class WebFeaturedCarousel extends StatefulWidget {
  const WebFeaturedCarousel({super.key, required this.books});

  final List<BookSummary> books;

  @override
  State<WebFeaturedCarousel> createState() => _WebFeaturedCarouselState();
}

class _WebFeaturedCarouselState extends State<WebFeaturedCarousel> {
  final _controller = PageController();
  int _page = 0;

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
      return WebFeaturedCard(book: books.first, index: 0);
    }
    return Column(
      children: [
        SizedBox(
          height: 208,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: books.length,
            itemBuilder: (context, i) =>
                WebFeaturedCard(book: books[i], index: i),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < books.length; i++)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: AppMotion.short,
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: AppMotion.short,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
