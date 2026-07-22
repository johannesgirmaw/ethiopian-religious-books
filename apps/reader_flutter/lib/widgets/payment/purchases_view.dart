import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../providers/nav_visibility_providers.dart';
import '../../providers/payment_providers.dart';
import '../../utils/money_format.dart';
import '../app_state_view.dart';
import '../skeleton_loader.dart';
import 'payment_method_icons.dart';
import 'payment_status_chip.dart';
import 'payments_page_header.dart';
import 'purchase_detail_sheet.dart';

/// Shared, responsive "My purchases" list: the current user's payment
/// transactions with live status. Used by the mobile, web and desktop adapters.
class PurchasesView extends ConsumerWidget {
  const PurchasesView({super.key, this.showHeader = false});

  /// Render a page title header (web/desktop, where the scaffold has none).
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myTransactionsProvider);

    final content = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myTransactionsProvider);
        ref.invalidate(hasPurchasesProvider);
      },
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonCardGroup(count: 4),
        ),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppStateView(
              title: l10n.paymentErrorGeneric,
              message: '$e',
              icon: Icons.receipt_long_outlined,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(myTransactionsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                AppStateView(
                  title: l10n.paymentMyPurchases,
                  message: l10n.paymentNoPurchases,
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _PurchaseTile(txn: items[i]),
              ),
            ),
          );
        },
      ),
    );

    if (!showHeader) return content;
    return Column(
      children: [
        PaymentsPageHeader(
          title: l10n.paymentMyPurchases,
          subtitle: l10n.paymentPurchasesSubtitle,
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.txn});

  final PaymentTransaction txn;

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final method = txn.method;
    return InkWell(
      onTap: () => showPurchaseDetail(context, txn),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    txn.bookTitle.isNotEmpty ? txn.bookTitle : l10n.paymentTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PaymentStatusChip(status: txn.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  formatMoney(txn.amount, txn.currency),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (method != null) ...[
                  const SizedBox(width: 10),
                  Icon(paymentMethodIcon(method),
                      size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    paymentMethodLabel(method, l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                if (txn.createdAt != null)
                  Text(
                    _formatDate(txn.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            if (txn.transactionReference.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.paymentSuccessReference(txn.transactionReference),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
