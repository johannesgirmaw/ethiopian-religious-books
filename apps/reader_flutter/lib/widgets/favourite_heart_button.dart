import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../providers/engagement_providers.dart';

/// White circular heart that reflects and toggles the server favourite state.
class FavouriteHeartButton extends ConsumerWidget {
  const FavouriteHeartButton({super.key, required this.bookId, this.size = 30});

  final String bookId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked =
        ref.watch(favouriteIdsProvider).valueOrNull?.contains(bookId) ?? false;

    return GestureDetector(
      onTap: () async {
        try {
          await setFavourite(ref, bookId, add: !liked);
        } catch (_) {/* offline / unauthenticated — ignore */}
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.listRow,
        ),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: size * 0.52,
          color: liked ? AppColors.crimson : AppColors.textTertiary,
        ),
      ),
    );
  }
}
