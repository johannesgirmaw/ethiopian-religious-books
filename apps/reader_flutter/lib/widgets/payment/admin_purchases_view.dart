import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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

/// Columns the orders table can be sorted by (client-side, on the loaded page).
enum _SortCol { date, customer, book, total, status }

/// Avatar tint palette — stable per customer so a row keeps its colour.
const _avatarPalette = <Color>[
  AppColors.primary,
  AppColors.primaryDeep,
  AppColors.primaryMid,
  AppColors.accent,
  AppColors.successText,
  AppColors.crimson,
];

Color _avatarColor(String seed) =>
    seed.isEmpty ? AppColors.primary : _avatarPalette[seed.codeUnitAt(0) % _avatarPalette.length];

String _initial(String text) {
  final t = text.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}

/// Per-row actions shared by the table's kebab/right-click menu and the
/// mobile card. Wired to the state's approve/reject/review/copy handlers.
class _RowActions {
  const _RowActions({
    required this.onReview,
    required this.onApprove,
    required this.onReject,
    required this.onCopyReference,
  });

  final void Function(PaymentTransaction) onReview;
  final void Function(PaymentTransaction) onApprove;
  final void Function(PaymentTransaction) onReject;
  final void Function(PaymentTransaction) onCopyReference;
}

/// Builds the context-menu entries for one transaction. Approve/Reject only
/// appear while the payment is still actionable (not terminal); Copy reference
/// only when there is one.
List<PopupMenuEntry<String>> _rowMenuEntries(
  BuildContext context,
  PaymentTransaction txn,
) {
  final l10n = AppLocalizations.of(context);
  final canAct = !txn.status.isTerminal;
  PopupMenuItem<String> item(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  return [
    item('review', Icons.visibility_outlined, l10n.adminReview,
        AppColors.textPrimary),
    if (canAct)
      item('approve', Icons.check_circle_outline, l10n.adminApprove,
          AppColors.successText),
    if (canAct)
      item('reject', Icons.cancel_outlined, l10n.adminReject,
          AppColors.errorText),
    if (txn.transactionReference.trim().isNotEmpty)
      item('copy_ref', Icons.copy_outlined, l10n.adminCopyReference,
          AppColors.textPrimary),
  ];
}

void _dispatchRowAction(
  String value,
  PaymentTransaction txn,
  _RowActions actions,
) {
  switch (value) {
    case 'review':
      actions.onReview(txn);
      break;
    case 'approve':
      actions.onApprove(txn);
      break;
    case 'reject':
      actions.onReject(txn);
      break;
    case 'copy_ref':
      actions.onCopyReference(txn);
      break;
  }
}

/// Admin "Orders & payments": dashboard totals, a status filter, search, a
/// sortable + paginated transactions table (cards on mobile), and a review sheet
/// to approve (→ complete + ledger) or reject manual payments.
class AdminPurchasesView extends ConsumerStatefulWidget {
  const AdminPurchasesView({super.key, this.showHeader = false});

  final bool showHeader;

  @override
  ConsumerState<AdminPurchasesView> createState() => _AdminPurchasesViewState();
}

class _AdminPurchasesViewState extends ConsumerState<AdminPurchasesView> {
  // Default to All so an order stays visible (with its new status) after review.
  String _filter = '';
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SortCol _sortCol = _SortCol.date;
  bool _sortAsc = false; // newest first by default
  int _page = 0;
  int _rowsPerPage = 10;

  static const _rowsPerPageOptions = <int>[5,10, 25, 50, 100];

  static const _filters = <PaymentStatus?>[
    null, // All
    PaymentStatus.onReview,
    PaymentStatus.pending,
    PaymentStatus.completed,
    PaymentStatus.rejected,
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  PaymentStatus? get _statusFilter {
    for (final s in _filters) {
      if (s != null && s.apiValue == _filter) return s;
    }
    return null;
  }

  /// Search-filter then sort the loaded list (pagination is applied by the caller).
  List<PaymentTransaction> _process(List<PaymentTransaction> src) {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? List<PaymentTransaction>.of(src)
        : src
            .where((t) =>
                t.userEmail.toLowerCase().contains(q) ||
                t.bookTitle.toLowerCase().contains(q) ||
                t.transactionReference.toLowerCase().contains(q))
            .toList();

    int base(PaymentTransaction a, PaymentTransaction b) {
      switch (_sortCol) {
        case _SortCol.date:
          return (a.createdAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(b.createdAt?.millisecondsSinceEpoch ?? 0);
        case _SortCol.customer:
          return a.userEmail.toLowerCase().compareTo(b.userEmail.toLowerCase());
        case _SortCol.book:
          return a.bookTitle.toLowerCase().compareTo(b.bookTitle.toLowerCase());
        case _SortCol.total:
          return a.amount.compareTo(b.amount);
        case _SortCol.status:
          return a.status.apiValue.compareTo(b.status.apiValue);
      }
    }

    list.sort((a, b) => _sortAsc ? base(a, b) : -base(a, b));
    return list;
  }

  void _onSort(_SortCol col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = col != _SortCol.date; // dates default newest-first
      }
      _page = 0;
    });
  }

  void _setFilter(String value) => setState(() {
        _filter = value;
        _page = 0;
      });

  void _setQuery(String value) => setState(() {
        _query = value;
        _page = 0;
      });

  void _setRowsPerPage(int value) => setState(() {
        _rowsPerPage = value;
        _page = 0;
      });

  // --- Row actions (context menu) ----------------------------------------

  Future<void> _runAction(
    Future<void> Function() op,
    String successMsg,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      refreshAdminPaymentsW(ref);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(paymentErrorMessage(e, l10n.paymentErrorGeneric))),
      );
    }
  }

  Future<void> _approve(PaymentTransaction txn) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.adminApproveConfirm),
        content: Text(
          txn.bookTitle.isEmpty ? txn.userEmail : txn.bookTitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successText,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.adminApprove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(
      () => ref.read(adminPaymentRepositoryProvider).approve(txn.id),
      l10n.adminApproved,
    );
  }

  Future<void> _reject(PaymentTransaction txn) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.adminReject),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.adminRejectReason,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.adminReject),
          ),
        ],
      ),
    );
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    await _runAction(
      () => ref.read(adminPaymentRepositoryProvider).reject(txn.id, note: note),
      l10n.adminRejected,
    );
  }

  Future<void> _copyReference(PaymentTransaction txn) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: txn.transactionReference));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.paymentCopied)));
  }

  _RowActions get _rowActions => _RowActions(
        onReview: _openReview,
        onApprove: _approve,
        onReject: _reject,
        onCopyReference: _copyReference,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dashAsync = ref.watch(adminPaymentDashboardProvider);
    final txnsAsync = ref.watch(adminTransactionsProvider(_filter));

    Widget scrollable({required List<Widget> children}) {
      return RefreshIndicator(
        onRefresh: () async => refreshAdminPaymentsW(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: children,
        ),
      );
    }

    // Dashboard + status tabs + search + active-filter chips. Shown above every
    // state (loading / error / data) so the controls never jump around.
    List<Widget> controls() => [
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
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _filter == (s?.apiValue ?? '')
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _filter == (s?.apiValue ?? '')
                        ? AppColors.primaryDeep
                        : AppColors.textSecondary,
                  ),
                  backgroundColor: AppColors.surfaceCard,
                  onSelected: (_) => _setFilter(s?.apiValue ?? ''),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _SearchField(
            controller: _searchCtrl,
            hint: l10n.adminSearchOrdersHint,
            onChanged: _setQuery,
          ),
          _ActiveFilters(
            statusLabel: _statusFilter == null
                ? null
                : paymentStatusLabel(_statusFilter!, l10n),
            query: _query.trim(),
            onClearStatus: () => _setFilter(''),
            onClearQuery: () {
              _searchCtrl.clear();
              _setQuery('');
            },
            onClearAll: () {
              _searchCtrl.clear();
              setState(() {
                _filter = '';
                _query = '';
                _page = 0;
              });
            },
          ),
          const SizedBox(height: AppSpace.md),
        ];

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return txnsAsync.when(
          loading: () => scrollable(
            children: [
              ...controls(),
              const SkeletonCardGroup(count: 3),
            ],
          ),
          error: (e, _) => scrollable(
            children: [
              ...controls(),
              AppStateView(
                title: l10n.paymentErrorGeneric,
                message: '$e',
                icon: Icons.receipt_long_outlined,
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.invalidate(adminTransactionsProvider(_filter)),
              ),
            ],
          ),
          data: (items) {
            final processed = _process(items);
            final total = processed.length;

            // Empty: distinguish "no orders at all" from "search filtered all out".
            if (total == 0) {
              return scrollable(
                children: [
                  ...controls(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(items.isEmpty
                          ? l10n.adminNoOrders
                          : l10n.adminNoMatchingOrders),
                    ),
                  ),
                ],
              );
            }

            final pageCount = (total + _rowsPerPage - 1) ~/ _rowsPerPage;
            final page = _page.clamp(0, pageCount - 1);
            final start = page * _rowsPerPage;
            final end = (start + _rowsPerPage) > total ? total : start + _rowsPerPage;
            final slice = processed.sublist(start, end);

            final pagination = _PaginationBar(
              page: page,
              pageCount: pageCount,
              rangeStart: start + 1,
              rangeEnd: end,
              total: total,
              compact: !wide,
              rowsPerPage: _rowsPerPage,
              rowsPerPageOptions: _rowsPerPageOptions,
              onRowsPerPageChanged: _setRowsPerPage,
              onSelect: (p) => setState(() => _page = p.clamp(0, pageCount - 1)),
            );

            if (wide) {
              return scrollable(
                children: [
                  ...controls(),
                  _OrdersTable(
                    items: slice,
                    sortCol: _sortCol,
                    sortAsc: _sortAsc,
                    onSort: _onSort,
                    actions: _rowActions,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  pagination,
                ],
              );
            }
            return scrollable(
              children: [
                ...controls(),
                for (final txn in slice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminOrderCard(
                      txn: txn,
                      actions: _rowActions,
                    ),
                  ),
                const SizedBox(height: AppSpace.xs),
                pagination,
              ],
            );
          },
        );
      },
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
    // Wide screens (web / desktop) get a centered, horizontally-laid-out dialog;
    // narrow screens keep the draggable bottom sheet.
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      await showDialog<void>(
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
            constraints: const BoxConstraints(maxWidth: 880, maxHeight: 620),
            child: _ReviewSheet(txn: txn),
          ),
        ),
      );
      return;
    }
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
// Search field
// ---------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final field = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textTertiary,
            ),
            prefixIcon: const Icon(Icons.search,
                size: 20, color: AppColors.textTertiary),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textTertiary,
                    splashRadius: 18,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        );
      },
    );

    // Constrain width on wide screens so it reads like a toolbar, not a banner.
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 360, child: field),
          );
        }
        return field;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// "Showing results for:" active-filter chips
// ---------------------------------------------------------------------------
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.statusLabel,
    required this.query,
    required this.onClearStatus,
    required this.onClearQuery,
    required this.onClearAll,
  });

  final String? statusLabel;
  final String query;
  final VoidCallback onClearStatus;
  final VoidCallback onClearQuery;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final hasStatus = statusLabel != null;
    final hasQuery = query.isNotEmpty;
    if (!hasStatus && !hasQuery) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.adminShowingResultsFor,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (hasStatus)
            _RemovableChip(label: statusLabel!, onRemove: onClearStatus),
          if (hasQuery)
            _RemovableChip(label: '“$query”', onRemove: onClearQuery),
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primaryDeep,
            ),
            child: Text(
              l10n.adminClearFilters,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDeep,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
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
  const _OrdersTable({
    required this.items,
    required this.sortCol,
    required this.sortAsc,
    required this.onSort,
    required this.actions,
  });

  final List<PaymentTransaction> items;
  final _SortCol sortCol;
  final bool sortAsc;
  final void Function(_SortCol) onSort;
  final _RowActions actions;

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
        boxShadow: AppShadows.panel,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with clickable sort affordances.
          Container(
            color: AppColors.surfaceSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _SortHeader(
                  label: l10n.paymentDate,
                  flex: 2,
                  col: _SortCol.date,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                _SortHeader(
                  label: l10n.adminCustomer,
                  flex: 3,
                  col: _SortCol.customer,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                _SortHeader(
                  label: l10n.adminBook,
                  flex: 4,
                  col: _SortCol.book,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                _SortHeader(
                  label: l10n.paymentTotal,
                  flex: 2,
                  col: _SortCol.total,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                _SortHeader(
                  label: l10n.paymentMethod,
                  flex: 2,
                  col: null,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                _SortHeader(
                  label: l10n.paymentStatusColumn,
                  flex: 2,
                  col: _SortCol.status,
                  active: sortCol,
                  asc: sortAsc,
                  onSort: onSort,
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _OrderTableRow(
              txn: items[i],
              l10n: l10n,
              zebra: i.isOdd,
              actions: actions,
            ),
        ],
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.flex,
    required this.col,
    required this.active,
    required this.asc,
    required this.onSort,
  });

  final String label;
  final int flex;
  final _SortCol? col;
  final _SortCol active;
  final bool asc;
  final void Function(_SortCol) onSort;

  static const _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final isActive = col != null && col == active;
    final icon = col == null
        ? null
        : isActive
            ? (asc ? Icons.arrow_upward : Icons.arrow_downward)
            : Icons.unfold_more;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: _style.copyWith(
              color: isActive ? AppColors.primaryDeep : AppColors.textSecondary,
            ),
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 3),
          Icon(
            icon,
            size: 13,
            color: isActive ? AppColors.primary : AppColors.textTertiary,
          ),
        ],
      ],
    );

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: col == null
            ? content
            : InkWell(
                onTap: () => onSort(col!),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: content,
              ),
      ),
    );
  }
}

class _OrderTableRow extends StatelessWidget {
  const _OrderTableRow({
    required this.txn,
    required this.l10n,
    required this.zebra,
    required this.actions,
  });

  final PaymentTransaction txn;
  final AppLocalizations l10n;
  final bool zebra;
  final _RowActions actions;

  // Desktop/web right-click → same menu as the kebab button.
  Future<void> _showContextMenu(BuildContext context, Offset globalPos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPos & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: _rowMenuEntries(context, txn),
    );
    if (value != null) _dispatchRowAction(value, txn, actions);
  }

  @override
  Widget build(BuildContext context) {
    final method =
        txn.method == null ? '—' : paymentMethodLabel(txn.method!, l10n);
    final ref = txn.transactionReference.trim();
    final email = txn.userEmail.isEmpty ? '—' : txn.userEmail;

    return Material(
      color: zebra
          ? AppColors.surfaceSoft.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: () => actions.onReview(txn),
        onSecondaryTapDown: (d) => _showContextMenu(context, d.globalPosition),
        hoverColor: AppColors.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Row(
                  children: [
                    _Avatar(seed: email),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TableTextCell(
                        text: email,
                        style: _OrdersTable._cellPrimary,
                        maxLines: 1,
                      ),
                    ),
                  ],
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
                  mainAxisSize: MainAxisSize.min,
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
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _RowActionsMenu(txn: txn, actions: actions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kebab (⋮) button opening the per-row context menu. Used by both the table
/// rows and the mobile cards.
class _RowActionsMenu extends StatelessWidget {
  const _RowActionsMenu({required this.txn, required this.actions});

  final PaymentTransaction txn;
  final _RowActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.adminActionsTooltip,
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      splashRadius: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      itemBuilder: (context) => _rowMenuEntries(context, txn),
      onSelected: (value) => _dispatchRowAction(value, txn, actions),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(seed);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initial(seed),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
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
// Pagination bar
// ---------------------------------------------------------------------------
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageCount,
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.onSelect,
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.onRowsPerPageChanged,
    this.compact = false,
  });

  final int page; // 0-based
  final int pageCount;
  final int rangeStart; // 1-based, inclusive
  final int rangeEnd; // 1-based, inclusive
  final int total;
  final bool compact;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final ValueChanged<int> onRowsPerPageChanged;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rangeText = Text(
      l10n.adminOrdersRange(rangeStart, rangeEnd, total),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );

    final selector = _RowsPerPageSelector(
      value: rowsPerPage,
      options: rowsPerPageOptions,
      onChanged: onRowsPerPageChanged,
    );

    final prev = _NavButton(
      icon: Icons.chevron_left,
      enabled: page > 0,
      onTap: () => onSelect(page - 1),
    );
    final next = _NavButton(
      icon: Icons.chevron_right,
      enabled: page < pageCount - 1,
      onTap: () => onSelect(page + 1),
    );

    if (compact) {
      // Selector on its own line so the pager never overflows on narrow phones.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [selector, const Spacer(), rangeText]),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              const Spacer(),
              prev,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${page + 1} / $pageCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              next,
            ],
          ),
        ],
      );
    }

    // Windowed page numbers: up to 5 around the current page.
    final windowStart = (page - 2).clamp(0, (pageCount - 5).clamp(0, pageCount));
    final windowEnd = (windowStart + 5) > pageCount ? pageCount : windowStart + 5;

    return Row(
      children: [
        selector,
        const SizedBox(width: AppSpace.md),
        rangeText,
        const Spacer(),
        prev,
        const SizedBox(width: 4),
        for (var p = windowStart; p < windowEnd; p++) ...[
          _PageButton(
            label: '${p + 1}',
            selected: p == page,
            onTap: () => onSelect(p),
          ),
          const SizedBox(width: 4),
        ],
        next,
      ],
    );
  }
}

class _RowsPerPageSelector extends StatelessWidget {
  const _RowsPerPageSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.adminRowsPerPage,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items: [
                for (final o in options)
                  DropdownMenuItem<int>(value: o, child: Text('$o')),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SquareTap(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 20,
        color: enabled ? AppColors.textSecondary : AppColors.textTertiary.withValues(alpha: 0.4),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SquareTap(
      onTap: onTap,
      selected: selected,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SquareTap extends StatelessWidget {
  const _SquareTap({
    required this.child,
    required this.onTap,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: selected
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile card
// ---------------------------------------------------------------------------
class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.txn, required this.actions});

  final PaymentTransaction txn;
  final _RowActions actions;

  @override
  Widget build(BuildContext context) {
    final email = txn.userEmail.isEmpty ? '—' : txn.userEmail;
    return InkWell(
      onTap: () => actions.onReview(txn),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.listRow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(seed: email),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.bookTitle.isEmpty ? '—' : txn.bookTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PaymentStatusChip(status: txn.status),
                _RowActionsMenu(txn: txn, actions: actions),
              ],
            ),
            const SizedBox(height: 10),
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

  bool get _hasReceipt =>
      widget.txn.method?.isManual == true ||
      widget.txn.receiptUrl.isNotEmpty;

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
          child: _footer(context, wide: true),
        ),
      ],
    );
  }

  // --- Narrow (bottom sheet): single stacked column -------------------------
  Widget _narrowLayout(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
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
              _footer(context, wide: false),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header: eyebrow + book title + customer, status chip, close ----------
  Widget _header(BuildContext context, {required bool showClose}) {
    final l10n = AppLocalizations.of(context);
    final txn = widget.txn;
    final email = txn.userEmail.isEmpty ? '—' : txn.userEmail;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.adminOrderDetail.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          txn.bookTitle.isEmpty ? '—' : txn.bookTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline,
                size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                email,
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

  // --- Details column: money breakdown + payment facts ----------------------
  Widget _detailsColumn(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final txn = widget.txn;
    final authorShare = txn.amount - txn.commissionAmount;

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
      DetailRow(label: l10n.paymentDate, value: _formatDate(txn.createdAt)),
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
          child: Column(
            children: [
              _amountRow(
                l10n.paymentTotal,
                formatMoney(txn.amount, txn.currency),
                strong: true,
              ),
              const SizedBox(height: 8),
              _amountRow(
                l10n.paymentCommission,
                '− ${formatMoney(txn.commissionAmount, txn.currency)}',
                muted: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.border),
              ),
              _amountRow(
                l10n.adminAuthorRevenue,
                formatMoney(authorShare, txn.currency),
                accent: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        ...facts,
      ],
    );
  }

  Widget _amountRow(
    String label,
    String value, {
    bool strong = false,
    bool muted = false,
    bool accent = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: muted ? 12.5 : 13,
              fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
              color: muted ? AppColors.textTertiary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: (strong || accent) ? 15.5 : 13,
            fontWeight: (strong || accent) ? FontWeight.w800 : FontWeight.w600,
            color: accent
                ? AppColors.primaryDeep
                : muted
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
          ),
        ),
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
        ReceiptPreview(transaction: widget.txn, height: height),
      ],
    );
  }

  // --- Footer: error + reason + actions -------------------------------------
  Widget _footer(BuildContext context, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final txn = widget.txn;
    final canAct = !txn.status.isTerminal;

    final children = <Widget>[];

    if (_error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline,
                  size: 16, color: AppColors.errorText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.errorText, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!canAct) {
      final closeBtn = FilledButton.tonal(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        child: Text(l10n.close),
      );
      children.add(
        wide
            ? Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 160, child: closeBtn),
              )
            : closeBtn,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final reject = OutlinedButton(
      onPressed: _busy ? null : () => _act(approve: false),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.errorText,
        side: const BorderSide(color: AppColors.errorBorder),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      child: Text(l10n.adminReject),
    );

    final approve = FilledButton(
      onPressed: _busy ? null : () => _act(approve: true),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.successText,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
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
    );

    children.add(_reasonField(l10n));
    children.add(const SizedBox(height: AppSpace.md));
    children.add(
      wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                reject,
                const SizedBox(width: AppSpace.sm),
                approve,
              ],
            )
          : Row(
              children: [
                Expanded(child: reject),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: approve),
              ],
            ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _reasonField(AppLocalizations l10n) {
    return TextField(
      controller: _note,
      minLines: 1,
      maxLines: 3,
      style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.adminRejectReason,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}
