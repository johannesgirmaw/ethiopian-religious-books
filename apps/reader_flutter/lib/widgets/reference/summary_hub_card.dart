import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';

/// Premium horizontal stats card — Ethiopian sacred aesthetic.
class SummaryHubCard extends StatelessWidget {
  const SummaryHubCard({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.contentLabel,
    required this.contentIcon,
    required this.onTap,
  });

  final String title;
  final String categoryLabel;
  final IconData categoryIcon;
  final String contentLabel;
  final IconData contentIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.elevated,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                categoryIcon,
                color: AppColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),

            // Title + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        categoryIcon,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          categoryLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        contentIcon,
                        size: 13,
                        color: AppColors.accent.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          contentLabel,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
