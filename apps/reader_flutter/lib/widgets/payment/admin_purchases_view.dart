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
import 'payments_page_header.dart';
import 'receipt_preview.dart';

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// Admin "Orders & payments": dashboard totals, a status filter, the
/// transactions (table on wide screens, cards on mobile), and a review sheet to
/// approve (→ complete + ledger) or reject manual payments.
class AdminPurchasesView extends ConsumerStatefulWidget {
  const AdminPurchasesView({super.key, this.showHeader = false});

  final bool showHeader;

  @override
  ConsumerState<AdminPurchasesView> createState() => _AdminPurchasesViewState();
}

class _AdminPurchasesViewState extends ConsumerState<AdminPurchasesView> {
  // Default to All so an order stays visible (with its new status) after review.
  String _filter = '';

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

    final body = RefreshIndicator(
      onRefresh: () async => refreshAdminPaymentsW(ref),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return ListView(
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
                      label: Text(s == null
                          ? l10n.adminOrdersAllStatuses
                          : paymentStatusLabel(s, l10n)),
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
                  return wide
                      ? _OrdersTable(items: items, onReview: _openReview)
                      : Column(
                          children: [
                            for (final txn in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AdminOrderCard(
                                  txn: txn,
                                  onReview: () => _openReview(txn),
                                ),
                              ),
                          ],
                        );
                },
              ),
            ],
          );
        },
      ),
    );

    if (!widget.showHeader) return body;
    return Column(
      children: [
        PaymentsPageHeader(
          title: l10n.adminPaymentsTitle,
          subtitle: l10n.adminOrdersSubtitle,
        ),
        Expanded(child: body),
      ],
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

// ---------------------------------------------------------------------------
// Dashboard summary
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Desktop / web table
// ---------------------------------------------------------------------------
class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.items, required this.onReview});

  final List<PaymentTransaction> items;
  final void Function(PaymentTransaction) onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 720),
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceSoft),
            columns: [
              DataColumn(label: Text(l10n.paymentDate)),
              DataColumn(label: Text(l10n.adminCustomer)),
              DataColumn(label: Text(l10n.adminBook)),
              DataColumn(label: Text(l10n.paymentTotal)),
              DataColumn(label: Text(l10n.paymentMethod)),
              DataColumn(label: Text(l10n.paymentStatusColumn)),
              const DataColumn(label: Text('')),
            ],
            rows: [
              for (final txn in items)
                DataRow(
                  cells: [
                    DataCell(Text(_formatDate(txn.createdAt))),
                    DataCell(_Truncated(txn.userEmail, 180)),
                    DataCell(_Truncated(txn.bookTitle, 200)),
                    DataCell(Text(formatMoney(txn.amount, txn.currency))),
                    DataCell(Text(txn.method == null
                        ? '—'
                        : paymentMethodLabel(txn.method!, l10n))),
                    DataCell(PaymentStatusChip(status: txn.status)),
                    DataCell(
                      FilledButton.tonal(
                        onPressed: () => onReview(txn),
                        child: Text(l10n.adminReview),
                      ),
                    ),
                  ],
                  onSelectChanged: (_) => onReview(txn),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Truncated extends StatelessWidget {
  const _Truncated(this.text, this.maxWidth);

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile card
// ---------------------------------------------------------------------------
class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.txn, required this.onReview});

  final PaymentTransaction txn;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onReview,
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
                Text(
                  _formatDate(txn.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: onReview,
                  child: Text(l10n.adminReview),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review sheet (approve / reject)
// ---------------------------------------------------------------------------
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                DetailRow(label: l10n.adminBook, value: txn.bookTitle),
                DetailRow(label: l10n.adminCustomer, value: txn.userEmail),
                DetailRow(
                  label: l10n.paymentTotal,
                  value: formatMoney(txn.amount, txn.currency),
                ),
                DetailRow(
                  label: l10n.paymentCommission,
                  value: formatMoney(txn.commissionAmount, txn.currency),
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
                DetailRow(label: l10n.paymentDate, value: _formatDate(txn.createdAt)),
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
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.errorText, fontSize: 13),
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
      ),
    );
  }
}
