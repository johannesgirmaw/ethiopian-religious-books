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
///
/// Wide screens (web / desktop) get a centered, horizontally-laid-out dialog;
/// narrow screens keep the draggable bottom sheet.
Future<void> showPurchaseDetail(
  BuildContext context,
  PaymentTransaction txn,
) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceCard,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 600),
          child: _PurchaseDetailSheet(txn: txn),
        ),
      ),
    );
  }
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

  bool get _hasReceipt =>
      txn.method?.isManual == true || txn.receiptUrl.isNotEmpty;

  String _date(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The dialog gives us room for a side-by-side layout; the bottom sheet
        // stays a single stacked column.
        final wide = constraints.maxWidth >= 620;
        return wide ? _wideLayout(context) : _narrowLayout(context);
      },
    );
  }

  // --- Wide (dialog): header · [details | receipt] · footer -----------------
  Widget _wideLayout(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: _hasReceipt
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detailsColumn(context)),
                const SizedBox(width: 28),
                SizedBox(
                  width: 300,
                  child: _receiptColumn(context, height: 300),
                ),
              ],
            )
          : _detailsColumn(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context, showClose: true),
        const Divider(height: 1, color: AppColors.borderSubtle),
        Flexible(child: body),
        const Divider(height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: _closeButton(context, wide: true),
        ),
      ],
    );
  }

  // --- Narrow (bottom sheet): single stacked column -------------------------
  Widget _narrowLayout(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
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
              _header(context, showClose: false),
              const SizedBox(height: AppSpace.md),
              _detailsColumn(context),
              if (_hasReceipt) ...[
                const SizedBox(height: AppSpace.md),
                _receiptColumn(context, height: 240),
              ],
              const SizedBox(height: AppSpace.md),
              _closeButton(context, wide: false),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header: eyebrow + book title + method, status chip, close ------------
  Widget _header(BuildContext context, {required bool showClose}) {
    final l10n = AppLocalizations.of(context);
    final method = txn.method;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.paymentPurchaseDetail.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          txn.bookTitle.isNotEmpty ? txn.bookTitle : l10n.paymentTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
        if (method != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(paymentMethodIcon(method),
                  size: 15, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  paymentMethodLabel(method, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        PaymentStatusChip(status: txn.status),
        if (showClose) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textTertiary,
            splashRadius: 18,
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );

    return showClose
        ? Padding(padding: const EdgeInsets.fromLTRB(24, 20, 16, 16), child: row)
        : row;
  }

  // --- Details column: amount card + payment facts --------------------------
  Widget _detailsColumn(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final facts = <Widget>[
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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.paymentTotal,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(txn.amount, txn.currency),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        ...facts,
      ],
    );
  }

  // --- Receipt column -------------------------------------------------------
  Widget _receiptColumn(BuildContext context, {required double height}) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.adminReceipt.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        ReceiptPreview(transaction: txn, height: height),
      ],
    );
  }

  Widget _closeButton(BuildContext context, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final btn = FilledButton.tonal(
      onPressed: () => Navigator.of(context).pop(),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      child: Text(l10n.close),
    );
    return wide
        ? Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 160, child: btn),
          )
        : btn;
  }
}
