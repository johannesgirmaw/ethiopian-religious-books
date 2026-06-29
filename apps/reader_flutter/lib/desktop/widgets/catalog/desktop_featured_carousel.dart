import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../models/book_models.dart';
import 'desktop_featured_card.dart';

/// "Popular" featured carousel for the desktop home.
class DesktopFeaturedCarousel extends StatefulWidget {
  const DesktopFeaturedCarousel({super.key, required this.books});

  final List<BookSummary> books;

  @override
  State<DesktopFeaturedCarousel> createState() =>
      _DesktopFeaturedCarouselState();
}

class _DesktopFeaturedCarouselState extends State<DesktopFeaturedCarousel> {
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
      return DesktopFeaturedCard(book: books.first, index: 0);
    }
    return Column(
      children: [
        SizedBox(
          height: 188,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: books.length,
            itemBuilder: (context, i) =>
                DesktopFeaturedCard(book: books[i], index: i),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < books.length; i++)
              GestureDetector(
                onTap: () => _controller.animateToPage(
                  i,
                  duration: AppMotion.short,
                  curve: Curves.easeOut,
                ),
                child: AnimatedContainer(
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
              ),
          ],
        ),
      ],
    );
  }
}
