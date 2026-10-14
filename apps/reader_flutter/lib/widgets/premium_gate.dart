import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/payment_providers.dart';
import '../security/device_identity.dart';
import '../storage/secure_book_store.dart';
import 'cover_badges.dart';

/// Returns true if [book] may be opened directly.
///
/// Order of checks for a priced title:
///  - viewer_can_manage (admin / creator / author) -> allow
///  - online entitlements say owned -> allow
///  - completed purchase in transactions (entitlements lag) -> allow
///  - network failure -> allow only with a valid this-device offline lease
///  - otherwise revoke local lease and route to checkout / info sheet
Future<bool> ensureBookUnlocked(
  BuildContext context,
  WidgetRef ref,
  BookSummary book,
) async {
  // Managers previewing an unpublished draft skip checkout.
  if (!book.isCatalogPublished && book.catalogVisibility != null) return true;

  // Server-attested manage right for this specific book.
  if (book.viewerCanManage) return true;

  if (!book.requiresPurchase) {
    if (!book.isPremium) return true;
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
              const Align(alignment: Alignment.centerLeft, child: PremiumBadge()),
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

  // Prefer live entitlements while online so refunds take effect immediately.
  var entitlementsOnline = false;
  try {
    final ids = await ref.read(entitledBookIdsProvider.future);
    entitlementsOnline = true;
    if (ids.contains(book.id)) return true;
  } catch (_) {
    // Offline / entitlements unavailable: fall back to a sealed local lease.
    try {
      final deviceId = await DeviceIdentity.deviceId();
      if (await SecureBookStore.hasValidOfflineAccess(
        book.id,
        deviceId: deviceId,
      )) {
        return true;
      }
    } catch (_) {}
  }

  // Entitlements can lag briefly after checkout — honor a completed transaction.
  try {
    final txns = await ref.read(myTransactionsProvider.future);
    final active = activePurchaseForBook(txns, book.id);
    if (!context.mounted) return false;
    if (active != null && active.status.isSuccessful) return true;
    if (active != null && active.status.isAwaitingReview) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(l10n.paymentInReviewBlocked),
        ),
      );
      return false;
    }
    if (active != null && active.status.resumesCheckout) {
      context.push('/payment/${book.id}');
      return false;
    }
  } catch (_) {}

  // Only drop the local lease once we know (online) the user is not entitled.
  if (entitlementsOnline) {
    await SecureBookStore.revokeOfflineLicense(book.id);
  }

  if (context.mounted) context.push('/payment/${book.id}');
  return false;
}
