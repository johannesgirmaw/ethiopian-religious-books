import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../providers/admin_payment_providers.dart';
import '../../providers/payment_providers.dart';
import '../../providers/session_notifier.dart';
import '../../utils/form_draft_controller.dart';
import '../../utils/form_draft_keys.dart';
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

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const _cellPrimary = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const _cellSecondary = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
    height: 1.3,
  );

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TableHeaderRow(
            labels: [
              l10n.paymentDate,
              l10n.adminCustomer,
              l10n.adminBook,
              l10n.paymentTotal,
              l10n.paymentMethod,
              l10n.paymentStatusColumn,
              '',
            ],
            style: _headerStyle,
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _OrderTableRow(
              txn: items[i],
              l10n: l10n,
              onReview: () => onReview(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.labels, required this.style});

  final List<String> labels;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _TableCell(flex: 2, child: Text(labels[0], style: style)),
          _TableCell(flex: 3, child: Text(labels[1], style: style)),
          _TableCell(flex: 4, child: Text(labels[2], style: style)),
          _TableCell(flex: 2, child: Text(labels[3], style: style)),
          _TableCell(flex: 2, child: Text(labels[4], style: style)),
          _TableCell(flex: 2, child: Text(labels[5], style: style)),
          SizedBox(
            width: 96,
            child: labels[6].isEmpty
                ? const SizedBox.shrink()
                : Text(labels[6], style: style),
          ),
        ],
      ),
    );
  }
}

class _OrderTableRow extends StatelessWidget {
  const _OrderTableRow({
    required this.txn,
    required this.l10n,
    required this.onReview,
  });

  final PaymentTransaction txn;
  final AppLocalizations l10n;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final method = txn.method == null
        ? '—'
        : paymentMethodLabel(txn.method!, l10n);
    final ref = txn.transactionReference.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReview,
        hoverColor: AppColors.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TableCell(
                flex: 2,
                child: Text(
                  _formatDate(txn.createdAt),
                  style: _OrdersTable._cellPrimary,
                ),
              ),
              _TableCell(
                flex: 3,
                child: _TableTextCell(
                  text: txn.userEmail.isEmpty ? '—' : txn.userEmail,
                  style: _OrdersTable._cellPrimary,
                ),
              ),
              _TableCell(
                flex: 4,
                child: _TableTextCell(
                  text: txn.bookTitle.isEmpty ? '—' : txn.bookTitle,
                  style: _OrdersTable._cellPrimary,
                  maxLines: 2,
                ),
              ),
              _TableCell(
                flex: 2,
                child: Text(
                  formatMoney(txn.amount, txn.currency),
                  style: _OrdersTable._cellPrimary.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              _TableCell(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method, style: _OrdersTable._cellPrimary),
                    if (ref.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _TableTextCell(
                          text: ref,
                          style: _OrdersTable._cellSecondary,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
              _TableCell(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PaymentStatusChip(status: txn.status),
                ),
              ),
              SizedBox(
                width: 96,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onReview,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.adminReview),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: child,
      ),
    );
  }
}

class _TableTextCell extends StatelessWidget {
  const _TableTextCell({
    required this.text,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      waitDuration: const Duration(milliseconds: 400),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
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
  late final FormDraftController _draft;

  @override
  void initState() {
    super.initState();
    _draft = FormDraftController(
      draftKey: FormDraftKeys.scope(
        userId: ref.read(sessionNotifierProvider).valueOrNull?.user?.id,
        formKey: FormDraftKeys.adminPaymentReview(widget.txn.id),
      ),
      capture: () => {'note': _note.text},
      restore: (data) {
        _note.text = data['note'] as String? ?? '';
      },
      isEmpty: (data) => (data['note'] as String? ?? '').trim().isEmpty,
    );
    _note.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    unawaited(_draft.persistNow());
    _note.removeListener(_draft.onChanged);
    _note.dispose();
    _draft.dispose();
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
      await _draft.clear();
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
