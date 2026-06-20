import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../providers/catalog_providers.dart';
import '../../../utils/catalog_book_visuals.dart';
import '../../design/desktop_tokens.dart';
import 'book_tile_hover.dart';

/// Compact catalog card for desktop library grids.
class DesktopBookCard extends ConsumerWidget {
  const DesktopBookCard({
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

    return DesktopBookTileHover(
      route: '/book/${book.id}',
      child: DecoratedBox(
        decoration: DesktopTokens.panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
                child: Stack(
                  children: [
                    const CatalogCrossWatermark(),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        icon,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ),
                    if ((meta?.progress ?? 0) > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: meta!.progress.clamp(0, 1),
                          minHeight: 2,
                          backgroundColor: Colors.white24,
                          color: DesktopTokens.accentGold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (book.authorCompiler?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.authorCompiler!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (meta?.chapterCount != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.catalogChapterCount(meta!.chapterCount!),
                      style: DesktopTokens.sectionLabelStyle.copyWith(
                        fontSize: 9,
                        height: 1.2,
                      ),
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

/// Table-style row for desktop list view.
class DesktopBookListRow extends ConsumerWidget {
  const DesktopBookListRow({
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

    return DesktopBookTileHover(
      route: '/book/${book.id}',
      child: DecoratedBox(
        decoration: DesktopTokens.panelDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 52,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.authorCompiler?.trim().isNotEmpty == true)
                      Text(
                        book.authorCompiler!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (meta?.chapterCount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    l10n.catalogChapterCount(meta!.chapterCount!),
                    style: DesktopTokens.sectionLabelStyle.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
