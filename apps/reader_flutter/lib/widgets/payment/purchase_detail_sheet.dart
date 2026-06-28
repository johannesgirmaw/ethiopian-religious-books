import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../utils/money_format.dart';
import 'payment_method_icons.dart';
import 'payment_status_chip.dart';
import 'receipt_preview.dart';

/// Read-only detail for one of the buyer's transactions (all payment details +
/// receipt). Opened from the My-purchases list.
Future<void> showPurchaseDetail(
  BuildContext context,
  PaymentTransaction txn,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => _PurchaseDetailSheet(txn: txn),
  );
}

class _PurchaseDetailSheet extends StatelessWidget {
  const _PurchaseDetailSheet({required this.txn});

  final PaymentTransaction txn;

  String _date(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      txn.bookTitle.isNotEmpty ? txn.bookTitle : l10n.paymentTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PaymentStatusChip(status: txn.status),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              DetailRow(
                label: l10n.paymentTotal,
                value: formatMoney(txn.amount, txn.currency),
              ),
              if (txn.method != null)
                DetailRow(
                  label: l10n.paymentMethod,
                  value: paymentMethodLabel(txn.method!, l10n),
                ),
              if (txn.bank != null)
                DetailRow(label: l10n.adminBank, value: txn.bank!.name),
              if (txn.transactionReference.isNotEmpty)
                DetailRow(
                  label: l10n.paymentTransactionReference,
                  value: txn.transactionReference,
                ),
              DetailRow(label: l10n.paymentDate, value: _date(txn.createdAt)),
              DetailRow(label: l10n.paymentOrderId, value: txn.id),
              if (txn.method?.isManual == true) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  l10n.adminReceipt,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                ReceiptPreview(transaction: txn),
              ],
              const SizedBox(height: AppSpace.md),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
