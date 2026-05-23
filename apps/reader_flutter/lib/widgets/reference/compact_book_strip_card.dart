import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Tall portrait book card for the horizontal "Continue Reading" strip.
class CompactBookStripCard extends StatelessWidget {
  const CompactBookStripCard({
    super.key,
    required this.title,
    required this.onTap,
    this.icon = Icons.menu_book_rounded,
  });

  final String title;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover area — gradient placeholder
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.heroVertical,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 32,
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                ),
              ),
              // Title area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search-result row with Read + Info dual actions.
class ReferenceBookSearchRow extends StatelessWidget {
  const ReferenceBookSearchRow({
    super.key,
    required this.bookId,
    required this.title,
  });

  final String bookId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: l10n.actionRead,
                  gradient: AppGradients.hero,
                  onPressed: () => context.push('/reader/$bookId'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: l10n.actionInfo,
                  onPressed: () => context.push('/book/$bookId'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.gradient,
  });

  final String label;
  final VoidCallback onPressed;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final hasGrad = gradient != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: hasGrad ? gradient : null,
          color: hasGrad ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: hasGrad
              ? null
              : Border.all(color: AppColors.border, width: 1.5),
          boxShadow: hasGrad ? AppShadows.card : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: hasGrad ? Colors.white : AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
