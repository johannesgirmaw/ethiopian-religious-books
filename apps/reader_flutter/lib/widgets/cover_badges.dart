import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import '../models/book_models.dart';
import '../utils/book_prices.dart';
import '../utils/money_format.dart';
import '../utils/resolve_cover_url.dart';

/// Shared cover overlays used by book cards on every platform.

/// Fills its slot with a network cover image, fading in once loaded. While
/// loading or on error it renders transparent, so a gradient placeholder
/// behind it shows through. Drop into a Stack via `Positioned.fill`.
class CoverImageFill extends StatelessWidget {
  const CoverImageFill({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveCoverUrl(url) ?? url;
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const SizedBox.expand(),
      errorBuilder: (context, error, stack) => const SizedBox.expand(),
    );
  }
}

/// ⭐ rating pill (white) — hidden by callers when there are no ratings yet.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.average, this.compact = false});

  final double average;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.listRow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: compact ? 11 : 13,
            color: AppColors.accent,
          ),
          const SizedBox(width: 3),
          Text(
            average.toStringAsFixed(1),
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "PREMIUM" pill.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.listRow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 9 : 11,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'PREMIUM',
            style: TextStyle(
              fontSize: compact ? 7.5 : 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled "READ NOW" CTA chip on the corner of a cover — matches the
/// Continue-reading primary button (cyan fill, white label).
class ReadNowBadge extends StatelessWidget {
  const ReadNowBadge({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 5 : 6,
        compact ? 3 : 4,
        compact ? 7 : 9,
        compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.listRow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: iconSize,
            color: Colors.white,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover chip for PDF Look Inside samples (opens `/pdf/:id/preview`).
class LookInsideBadge extends StatelessWidget {
  const LookInsideBadge({
    super.key,
    required this.label,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 10.0 : 12.0;
    final chip = Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 5 : 6,
        compact ? 3 : 4,
        compact ? 7 : 9,
        compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.listRow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.preview_outlined, size: iconSize, color: Colors.white),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: chip,
      ),
    );
  }
}

/// Frosted category icon chip used on gradient placeholder covers.
class CoverCategoryIcon extends StatelessWidget {
  const CoverCategoryIcon({
    super.key,
    required this.icon,
    this.size = 40,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

/// Price pill for a premium (priced) book's cover. Shows the price the buyer
/// pays; when on sale the original price is struck through beside it. Renders
/// nothing for free / non-premium titles.
class PriceBadge extends StatelessWidget {
  const PriceBadge({super.key, required this.book, this.compact = false});

  final BookSummary book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final quotes = book.priceQuotes;
    if (!book.requiresPurchase || quotes.isEmpty) {
      return const SizedBox.shrink();
    }
    final fs = compact ? 9.5 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.listRow,
      ),
      child: Text(
        formatBookPriceQuotes(quotes),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          height: 1.25,
        ),
      ),
    );
  }
}

/// Inline price for book detail pages: the final price, the struck-through
/// original and a discount chip when on sale. Renders nothing for free titles.
class BookPriceLabel extends StatelessWidget {
  const BookPriceLabel({super.key, required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final quotes = book.priceQuotes;
    if (!book.requiresPurchase || quotes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < quotes.length; i++) ...[
          if (i > 0) ...[
            const Text(
              '·',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          _DetailQuote(quote: quotes[i]),
        ],
      ],
    );
  }
}

class _DetailQuote extends StatelessWidget {
  const _DetailQuote({required this.quote});

  final BookPriceQuote quote;

  @override
  Widget build(BuildContext context) {
    final compareAt = quote.compareAt;
    final discount = compareAt != null && compareAt > 0
        ? (((compareAt - quote.amount) / compareAt) * 100).round()
        : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatMoney(quote.amount, quote.currency),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        if (compareAt != null) ...[
          const SizedBox(width: 8),
          Text(
            formatMoney(compareAt, quote.currency),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          if (discount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successSurface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Text(
                '-$discount%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.successText,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// White circular "favourite" heart with a local visual toggle — the data
/// model has no favourites yet.
class CoverHeartButton extends StatefulWidget {
  const CoverHeartButton({super.key, this.size = 30});

  final double size;

  @override
  State<CoverHeartButton> createState() => _CoverHeartButtonState();
}

class _CoverHeartButtonState extends State<CoverHeartButton> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _liked = !_liked),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.listRow,
        ),
        child: Icon(
          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: widget.size * 0.52,
          color: _liked ? AppColors.crimson : AppColors.textTertiary,
        ),
      ),
    );
  }
}
