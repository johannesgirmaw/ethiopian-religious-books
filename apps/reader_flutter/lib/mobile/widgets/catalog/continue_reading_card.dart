import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../providers/catalog_providers.dart';
import 'book_cover_poster.dart';

/// Wide "Continue Reading" strip with a progress bar (reference home).
class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({
    super.key,
    required this.book,
    required this.index,
  });

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final meta = ref.watch(catalogBookMetaProvider(book.id)).valueOrNull;
    final progress = (meta?.progress ?? 0).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final author = book.authorCompiler?.trim();

    return GestureDetector(
      onTap: () => context.push('/reader/${book.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.listRow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 66,
              child: BookCoverPoster(
                book: book,
                index: index,
                borderRadius: AppRadius.sm,
                iconSize: 22,
                showTitle: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      l10n.readNow.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  if (author != null && author.isNotEmpty)
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
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: progress == 0 ? null : progress,
                            minHeight: 5,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (percent > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          l10n.readingProgressPercent(percent),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
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
