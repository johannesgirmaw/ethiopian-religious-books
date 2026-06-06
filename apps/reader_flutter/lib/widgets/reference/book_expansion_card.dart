import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../models/book_models.dart';
import '../primitives/shell_primitives.dart';

/// Tappable book card for the browse list.
class BookExpansionCard extends StatelessWidget {
  const BookExpansionCard({
    super.key,
    required this.book,
    this.index,
  });

  final BookSummary book;
  final int? index;

  static const _accents = [
    AppColors.referencePrimary,
    AppColors.referenceSecondary,
    AppColors.referenceAccent,
    Color(0xFF2D6A4F),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = index ?? 0;
    final accent = _accents[idx % _accents.length];

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.cardV2),
          boxShadow: AppShadows.listRow,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            AppBookCover(
              size: 52,
              borderRadius: 12,
              accent: accent,
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.authorCompiler?.isNotEmpty == true)
                    Padding(
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
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
