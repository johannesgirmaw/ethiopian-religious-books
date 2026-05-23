import 'package:flutter/material.dart';

import '../../design/app_decorations.dart';
import '../../design/app_tokens.dart';

/// Language/category group — expandable list card.
class CategoryExpansionCard extends StatelessWidget {
  const CategoryExpansionCard({
    super.key,
    required this.index,
    required this.title,
    required this.itemCountLabel,
    required this.children,
    this.initiallyExpanded = false,
  });

  final int index;
  final String title;
  final String itemCountLabel;
  final List<Widget> children;
  final bool initiallyExpanded;

  static const _accents = [
    AppColors.referencePrimary,
    AppColors.referenceSecondary,
    AppColors.referenceAccent,
    Color(0xFF2D6A4F),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.listRow(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            backgroundColor: AppColors.surfaceCard,
            collapsedBackgroundColor: AppColors.surfaceCard,
            iconColor: AppColors.textTertiary,
            collapsedIconColor: AppColors.textTertiary,
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        itemCountLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}
