import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_decorations.dart';
import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import '../../utils/catalog_book_visuals.dart';

class CatalogBookGridTile extends ConsumerWidget {
  const CatalogBookGridTile({
    super.key,
    required this.book,
    required this.index,
  });

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meta = ref.watch(catalogBookMetaProvider(book.id)).valueOrNull;
    final icon = catalogBookIcon(book, index);
    final gradient = catalogBookGradient(index);
    final primaryOnCard = book.title;
    final secondaryOnCard = book.subtitle?.trim();

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.cardV2),
                boxShadow: AppShadows.listRow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const CatalogCrossWatermark(),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        const Spacer(),
                        Text(
                          primaryOnCard,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (secondaryOnCard?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryOnCard!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((meta?.progress ?? 0) > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: meta!.progress.clamp(0, 1),
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        color: AppColors.referenceAccent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            primaryOnCard,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          if (meta?.chapterCount != null)
            Text(
              l10n.catalogChapterCount(meta!.chapterCount!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class CatalogBookListTile extends ConsumerWidget {
  const CatalogBookListTile({
    super.key,
    required this.book,
    required this.index,
  });

  final BookSummary book;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meta = ref.watch(catalogBookMetaProvider(book.id)).valueOrNull;
    final icon = catalogBookIcon(book, index);
    final accent = catalogBookAccentColor(index);
    final progress = ((meta?.progress ?? 0) * 100).round();
    final showProgress = progress > 0;

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AppDecorations.listRow(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: catalogBookGradient(index),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (book.subtitle?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        book.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (meta?.chapterCount != null)
                        Text(
                          l10n.catalogChapterCount(meta!.chapterCount!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (showProgress) ...[
                        if (meta?.chapterCount != null)
                          const SizedBox(width: 8),
                        if (meta?.offlineCached == true)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.cloud_done_rounded,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        Text(
                          l10n.readingProgressPercent(progress),
                          style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
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
