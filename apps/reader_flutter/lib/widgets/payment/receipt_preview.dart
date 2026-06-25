import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';

/// Shows a transaction's uploaded receipt. Fetches the bytes through the
/// authenticated API client (the receipt endpoint is private) and renders an
/// image; non-image receipts (PDF) and missing files fall back to a labelled
/// placeholder. Shared by the buyer's purchase detail and the admin review.
class ReceiptPreview extends ConsumerWidget {
  const ReceiptPreview({super.key, required this.transaction, this.height = 240});

  final PaymentTransaction transaction;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (transaction.receiptUrl.isEmpty) {
      return _placeholder(
          l10n.adminNoReceipt, Icons.image_not_supported_outlined);
    }
    final bytesAsync = ref.watch(receiptBytesProvider(transaction.id));
    return bytesAsync.when(
      loading: () => SizedBox(
        height: height * 0.5,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => InkWell(
        onTap: () => ref.invalidate(receiptBytesProvider(transaction.id)),
        child: _placeholder(l10n.retry, Icons.refresh_rounded),
      ),
      data: (bytes) {
        if (bytes == null) {
          return _placeholder(
              l10n.adminNoReceipt, Icons.image_not_supported_outlined);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _placeholder(l10n.adminViewReceipt, Icons.description_outlined),
          ),
        );
      },
    );
  }

  Widget _placeholder(String label, IconData icon) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textTertiary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A labelled key/value row used in transaction detail panels.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
