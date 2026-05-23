import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import 'primitives/shell_primitives.dart';

enum BookCardLayout { compact, full }

/// Book row/card with equal Read and Info actions.
class BookListTile extends StatelessWidget {
  const BookListTile({
    super.key,
    required this.book,
    this.layout = BookCardLayout.full,
    this.width,
  });

  final BookSummary book;
  final BookCardLayout layout;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((book.primaryLanguage ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              book.primaryLanguage!.trim(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Text(
          book.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: layout == BookCardLayout.compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (book.authorCompiler?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            book.authorCompiler!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (layout == BookCardLayout.full &&
            book.summary != null &&
            book.summary!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            book.summary!,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => context.push('/reader/${book.id}'),
                child: Text(l10n.actionRead),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/book/${book.id}'),
                child: Text(l10n.actionInfo),
              ),
            ),
          ],
        ),
      ],
    );

    final card = AppPanel(
      padding: EdgeInsets.all(layout == BookCardLayout.compact ? 12 : 14),
      child: content,
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}
