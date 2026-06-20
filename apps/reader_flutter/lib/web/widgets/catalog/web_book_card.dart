import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../providers/catalog_providers.dart';
import '../../../utils/catalog_book_visuals.dart';
import '../../design/web_tokens.dart';
import 'book_tile_hover.dart';

/// Cover-first catalog card for web library grids.
class WebBookCard extends ConsumerWidget {
  const WebBookCard({
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
    final gradient = catalogBookGradient(index);
    final icon = catalogBookIcon(book, index);

    return WebBookTileHover(
      route: '/book/${book.id}',
      child: DecoratedBox(
        decoration: WebTokens.panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Stack(
                  children: [
                    const CatalogCrossWatermark(),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        icon,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 22,
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
                          backgroundColor: Colors.white24,
                          color: WebTokens.accentGold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (book.authorCompiler?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.authorCompiler!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (meta?.chapterCount != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.catalogChapterCount(meta!.chapterCount!),
                      style: WebTokens.sectionLabelStyle.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Table-style row for web list view.
class WebBookListRow extends ConsumerWidget {
  const WebBookListRow({
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
    final gradient = catalogBookGradient(index);
    final icon = catalogBookIcon(book, index);

    return WebBookTileHover(
      route: '/book/${book.id}',
      child: DecoratedBox(
        decoration: WebTokens.panelDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 68,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.authorCompiler?.trim().isNotEmpty == true)
                      Text(
                        book.authorCompiler!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (meta?.chapterCount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    l10n.catalogChapterCount(meta!.chapterCount!),
                    style: WebTokens.sectionLabelStyle.copyWith(fontSize: 10),
                  ),
                ),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
