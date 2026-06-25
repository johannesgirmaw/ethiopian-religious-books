import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../providers/admin_payment_providers.dart';
import '../../providers/payment_providers.dart';
import '../../utils/money_format.dart';
import '../app_state_view.dart';
import '../skeleton_loader.dart';
import 'payment_method_icons.dart';
import 'payment_status_chip.dart';

/// Admin "Orders & payments" surface: dashboard totals, a status filter, the
/// transaction list, and a review sheet to approve (→ complete + ledger) or
/// reject manual payments. Shared by the mobile/web/desktop admin adapters.
class AdminPurchasesView extends ConsumerStatefulWidget {
  const AdminPurchasesView({super.key});

  @override
  ConsumerState<AdminPurchasesView> createState() => _AdminPurchasesViewState();
}

class _AdminPurchasesViewState extends ConsumerState<AdminPurchasesView> {
  // Default to the queue that needs action.
  String _filter = PaymentStatus.onReview.apiValue;

  static const _filters = <PaymentStatus?>[
    null, // All
    PaymentStatus.onReview,
    PaymentStatus.pending,
    PaymentStatus.completed,
    PaymentStatus.rejected,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dashAsync = ref.watch(adminPaymentDashboardProvider);
    final txnsAsync = ref.watch(adminTransactionsProvider(_filter));

    return RefreshIndicator(
      onRefresh: () async => refreshAdminPaymentsW(ref),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              dashAsync.when(
                loading: () => const SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (d) => _DashboardSummary(dashboard: d),
              ),
              const SizedBox(height: AppSpace.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _filters)
                    ChoiceChip(
                      label: Text(
                        s == null ? l10n.filterAll : paymentStatusLabel(s, l10n),
                      ),
                      selected: _filter == (s?.apiValue ?? ''),
                      onSelected: (_) =>
                          setState(() => _filter = s?.apiValue ?? ''),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              txnsAsync.when(
                loading: () => const SkeletonCardGroup(count: 3),
                error: (e, _) => AppStateView(
                  title: l10n.paymentErrorGeneric,
                  message: '$e',
                  icon: Icons.receipt_long_outlined,
                  actionLabel: l10n.retry,
                  onAction: () =>
                      ref.invalidate(adminTransactionsProvider(_filter)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(l10n.adminNoOrders)),
                    );
                  }
                  return Column(
                    children: [
                      for (final txn in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AdminOrderTile(
                            txn: txn,
                            onReview: () => _openReview(txn),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReview(PaymentTransaction txn) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _ReviewSheet(txn: txn),
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.dashboard});

  final AdminPaymentDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatCard(
          label: l10n.adminPendingReviews,
          value: '${dashboard.pendingReviews}',
          accent: AppColors.accent,
        ),
        _StatCard(
          label: l10n.adminCompleted,
          value: '${dashboard.completedTransactions}',
          accent: AppColors.successText,
        ),
        _StatCard(
          label: l10n.adminGrossRevenue,
          value: dashboard.grossRevenue,
          accent: AppColors.primary,
        ),
        _StatCard(
          label: l10n.adminPlatformRevenue,
          value: dashboard.platformRevenue,
          accent: AppColors.primary,
        ),
        _StatCard(
          label: l10n.adminAuthorRevenue,
          value: dashboard.authorRevenue,
          accent: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderTile extends StatelessWidget {
  const _AdminOrderTile({required this.txn, required this.onReview});

  final PaymentTransaction txn;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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
                  txn.bookTitle,
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
          const SizedBox(height: 6),
          Text(
            txn.userEmail,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              const Spacer(),
              if (txn.status.isAwaitingReview)
                FilledButton.tonal(
                  onPressed: onReview,
                  child: Text(l10n.adminReview),
                )
              else
                TextButton(onPressed: onReview, child: Text(l10n.adminReview)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.txn});

  final PaymentTransaction txn;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _act({required bool approve}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminPaymentRepositoryProvider);
      if (approve) {
        await repo.approve(widget.txn.id);
      } else {
        await repo.reject(widget.txn.id, note: _note.text.trim());
      }
      refreshAdminPaymentsW(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(approve ? l10n.adminApproved : l10n.adminRejected)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = paymentErrorMessage(e, l10n.paymentErrorGeneric));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final txn = widget.txn;
    final canAct = !txn.status.isTerminal;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminOrderDetail,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  PaymentStatusChip(status: txn.status),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _DetailRow(label: l10n.adminBook, value: txn.bookTitle),
              _DetailRow(label: l10n.adminCustomer, value: txn.userEmail),
              _DetailRow(
                label: l10n.paymentTotal,
                value: formatMoney(txn.amount, txn.currency),
              ),
              if (txn.method != null)
                _DetailRow(
                  label: l10n.paymentTitle,
                  value: paymentMethodLabel(txn.method!, l10n),
                ),
              if (txn.bank != null)
                _DetailRow(label: l10n.adminBank, value: txn.bank!.name),
              if (txn.transactionReference.isNotEmpty)
                _DetailRow(
                  label: l10n.paymentTransactionReference,
                  value: txn.transactionReference,
                ),
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
              _ReceiptPreview(txn: txn),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorText, fontSize: 13),
                ),
              ],
              if (canAct) ...[
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: l10n.adminRejectReason,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _act(approve: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorText,
                          side: const BorderSide(color: AppColors.errorBorder),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(l10n.adminReject),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _act(approve: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.successText,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(l10n.adminApprove),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

class _ReceiptPreview extends ConsumerWidget {
  const _ReceiptPreview({required this.txn});

  final PaymentTransaction txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Empty receipt_url means nothing was uploaded.
    if (txn.receiptUrl.isEmpty) {
      return _placeholder(
          l10n.adminNoReceipt, Icons.image_not_supported_outlined);
    }
    final bytesAsync = ref.watch(receiptBytesProvider(txn.id));
    return bytesAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) =>
          _placeholder(l10n.paymentErrorGeneric, Icons.error_outline_rounded),
      data: (bytes) {
        if (bytes == null) {
          return _placeholder(
              l10n.adminNoReceipt, Icons.image_not_supported_outlined);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(
            bytes,
            height: 240,
            width: double.infinity,
            fit: BoxFit.contain,
            // Non-image receipts (e.g. PDF) can't render as an image.
            errorBuilder: (_, __, ___) =>
                _placeholder(l10n.adminViewReceipt, Icons.description_outlined),
          ),
        );
      },
    );
  }

  Widget _placeholder(String label, IconData icon) {
    return Container(
      height: 88,
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
