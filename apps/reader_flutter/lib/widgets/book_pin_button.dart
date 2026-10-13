import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/engagement_providers.dart';
import '../providers/session_notifier.dart';

/// Circular push-pin for platform admins to order Explore (incrementing rank).
class BookPinButton extends ConsumerWidget {
  const BookPinButton({super.key, required this.book, this.size = 30});

  final BookSummary book;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    if (user?.isPlatformAdmin != true) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final pinned = book.isPinned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: pinned ? l10n.bookUnpinTooltip : l10n.bookPinTooltip,
        child: GestureDetector(
          onTap: () async {
            try {
              await setBookPinned(ref, book.id, pin: !pinned);
            } catch (_) {/* offline / unauthorized */}
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              // Pinned: solid primary so the white pin reads clearly.
              // Unpinned: white disc with a dark pin (outline glyphs look blank).
              color: pinned ? AppColors.primary : Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.listRow,
              border: pinned
                  ? null
                  : Border.all(color: AppColors.line, width: 1),
            ),
            child: Transform.rotate(
              angle: pinned ? 0.4 : 0,
              child: Icon(
                Icons.push_pin,
                size: size * 0.52,
                color: pinned ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
