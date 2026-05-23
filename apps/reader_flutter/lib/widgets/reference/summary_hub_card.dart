import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/reference_assets.dart';

/// Large tappable summary card — matches mobile home `_buildCard` (bg1 + darken).
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
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage(ReferenceAssets.bgPattern),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black54,
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(categoryIcon, color: AppColors.accent, size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    categoryLabel,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(contentIcon, color: AppColors.referenceAccent, size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    contentLabel,
                    style: const TextStyle(color: AppColors.referenceAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
