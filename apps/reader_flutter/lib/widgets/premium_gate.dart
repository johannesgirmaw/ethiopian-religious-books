import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/payment_providers.dart';
import 'cover_badges.dart';

/// Returns true if [book] may be opened directly.
///
/// Order of checks for a premium title:
///  - already purchased (entitled) -> allow reading (true)
///  - priced & not purchased -> route to checkout (false)
///  - premium with no price -> informational sheet (false)
Future<bool> ensureBookUnlocked(
  BuildContext context,
  WidgetRef ref,
  BookSummary book,
) async {
  if (!book.isPremium) return true;

  // A completed purchase entitles the user to read.
  if (await userOwnsBook(ref, book.id)) return true;

  if (book.requiresPurchase) {
    if (context.mounted) context.push('/payment/${book.id}');
    return false;
  }
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: PremiumBadge(),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.premiumLockedTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.premiumLockedMessage,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.premiumGotIt),
            ),
          ],
        ),
      ),
    ),
  );
  return false;
}
