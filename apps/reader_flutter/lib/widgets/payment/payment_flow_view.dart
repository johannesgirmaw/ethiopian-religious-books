import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../providers/session_notifier.dart';
import '../../utils/form_draft_controller.dart';
import '../../utils/form_draft_keys.dart';
import '../../utils/money_format.dart';
import '../../utils/resolve_cover_url.dart';
import 'payment_method_icons.dart';

enum _Step { method, details, success }

/// Responsive, end-to-end payment flow used by the mobile, web and desktop
/// adapters (each wraps it in its own scaffold). Implements:
/// method selection → order summary → manual bank-transfer form → success.
///
/// Online gateways (Stripe/PayPal/Telebirr) are surfaced but currently report
/// "unavailable" until the backend gateways are configured.
class PaymentFlowView extends ConsumerStatefulWidget {
  const PaymentFlowView({super.key, required this.book, this.onClose});

  final BookSummary book;

  /// Called when the user finishes (Done on the success screen). Adapters use
  /// this to pop the route.
  final VoidCallback? onClose;

  @override
  ConsumerState<PaymentFlowView> createState() => _PaymentFlowViewState();
}

class _PaymentFlowViewState extends ConsumerState<PaymentFlowView> {
  _Step _step = _Step.method;
  PaymentMethodKind? _selectedMethod;
  String? _selectedBankId;
  Uint8List? _receiptBytes;
  String? _receiptName;
  final _referenceCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  PaymentTransaction? _transaction;
  String? _pendingTransactionId;
  late final FormDraftController _draft;

  String _draftKey() => FormDraftKeys.scope(
        userId: ref.read(sessionNotifierProvider).valueOrNull?.user?.id,
        formKey: FormDraftKeys.payment(widget.book.id),
      );

  @override
  void initState() {
    super.initState();
    _draft = FormDraftController(
      draftKey: _draftKey(),
      capture: _captureDraft,
      restore: _applyDraft,
      isEmpty: (data) {
        final reference = (data['reference'] as String? ?? '').trim();
        final method = data['method'] as String?;
        return reference.isEmpty && (method == null || method.isEmpty);
      },
    );
    _referenceCtrl.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    unawaited(ref.read(paymentMethodsProvider.future));
    unawaited(ref.read(banksProvider.future));

    final restored = await _draft.restoreIfPresent();
    if (restored) {
      await _hydrateRestoredDraft();
      if (!mounted) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    }
  }

  Future<void> _hydrateRestoredDraft() async {
    final txnId = _pendingTransactionId;
    _pendingTransactionId = null;

    if (_step == _Step.details) {
      if (txnId != null && txnId.isNotEmpty && _transaction == null) {
        try {
          final txn = await ref.read(transactionProvider(txnId).future);
          if (mounted) _transaction = txn;
        } catch (_) {
          if (mounted) {
            _step = _Step.method;
            _error = AppLocalizations.of(context).paymentErrorGeneric;
          }
        }
      }

      try {
        final banks = await ref.read(banksProvider.future);
        if (mounted &&
            _selectedBankId == null &&
            banks.length == 1) {
          _selectedBankId = banks.first.id;
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic> _captureDraft() => {
        'step': _step.index,
        'method': _selectedMethod?.name,
        'bankId': _selectedBankId,
        'reference': _referenceCtrl.text,
        'receiptName': _receiptName,
        'transactionId': _transaction?.id,
      };

  void _applyDraft(Map<String, dynamic> data) {
    final stepIndex = (data['step'] as num?)?.toInt();
    if (stepIndex != null &&
        stepIndex >= 0 &&
        stepIndex < _Step.values.length) {
      _step = _Step.values[stepIndex];
    }
    final methodName = data['method'] as String?;
    if (methodName != null) {
      for (final method in PaymentMethodKind.values) {
        if (method.name == methodName) {
          _selectedMethod = method;
          break;
        }
      }
    }
    _selectedBankId = data['bankId'] as String?;
    _referenceCtrl.text = data['reference'] as String? ?? '';
    _receiptName = data['receiptName'] as String?;
    _pendingTransactionId = data['transactionId'] as String?;
  }

  void _notifyDraftChanged() => _draft.onChanged();

  @override
  void dispose() {
    if (_step != _Step.success) {
      unawaited(_draft.persistNow());
    }
    _referenceCtrl.removeListener(_draft.onChanged);
    _referenceCtrl.dispose();
    _draft.dispose();
    super.dispose();
  }

  // --- actions -----------------------------------------------------------
  Future<void> _continueFromMethod() async {
    final l10n = AppLocalizations.of(context);
    final method = _selectedMethod;
    if (method == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.createTransaction(
        bookId: widget.book.id,
        method: method,
      );
      if (!mounted) return;
      if (method.isManual) {
        final banks = await ref.read(banksProvider.future);
        if (!mounted) return;
        setState(() {
          _transaction = result.transaction;
          if (_selectedBankId == null && banks.length == 1) {
            _selectedBankId = banks.first.id;
          }
          _step = _Step.details;
        });
        _notifyDraftChanged();
      } else {
        // Online gateways are not active yet; checkoutUrl will be null.
        setState(() => _error = l10n.paymentGatewayUnavailable);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = paymentErrorMessage(e, l10n.paymentErrorGeneric));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _receiptBytes = bytes;
      _receiptName = file.name;
    });
    _notifyDraftChanged();
  }

  Future<void> _submitReceipt() async {
    final l10n = AppLocalizations.of(context);
    final txn = _transaction;
    if (txn == null) return;
    if (_selectedBankId == null) {
      setState(() => _error = l10n.paymentBankRequired);
      return;
    }
    if (_receiptBytes == null || _receiptName == null) {
      setState(() => _error = l10n.paymentReceiptRequired);
      return;
    }
    if (_referenceCtrl.text.trim().isEmpty) {
      setState(() => _error = l10n.paymentReferenceRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final updated = await repo.submitReceipt(
        transactionId: txn.id,
        bytes: _receiptBytes!,
        filename: _receiptName!,
        transactionReference: _referenceCtrl.text.trim(),
        bankId: _selectedBankId,
      );
      if (!mounted) return;
      ref.invalidate(myTransactionsProvider);
      await _draft.clear();
      setState(() {
        _transaction = updated;
        _step = _Step.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = paymentErrorMessage(e, l10n.paymentErrorGeneric));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- build -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.xxl,
          ),
          children: [
            _StepIndicator(step: _step),
            const SizedBox(height: AppSpace.lg),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpace.md),
            ],
            switch (_step) {
              _Step.method => _MethodStep(
                  book: widget.book,
                  selected: _selectedMethod,
                  busy: _busy,
                  onSelect: (m) => setState(() {
                    _selectedMethod = m;
                    _notifyDraftChanged();
                  }),
                  onContinue: _selectedMethod == null || _busy
                      ? null
                      : _continueFromMethod,
                ),
              _Step.details => _ManualDetailsStep(
                  book: widget.book,
                  selectedBankId: _selectedBankId,
                  receiptName: _receiptName,
                  referenceController: _referenceCtrl,
                  busy: _busy,
                  onSelectBank: (id) => setState(() {
                    _selectedBankId = id;
                    _notifyDraftChanged();
                  }),
                  onPickReceipt: _pickReceipt,
                  onSubmit: _busy ? null : _submitReceipt,
                ),
              _Step.success => _SuccessStep(
                  transaction: _transaction,
                  onDone: widget.onClose,
                ),
            },
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = switch (step) {
      _Step.method => 0,
      _Step.details => 1,
      _Step.success => 2,
    };
    final labels = [
      l10n.paymentStepMethod,
      l10n.paymentStepDetails,
      l10n.paymentStepDone,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _StepDot(active: i <= index, label: labels[i], number: i + 1),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < index ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.label,
    required this.number,
  });

  final bool active;
  final String label;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: active ? AppColors.primary : AppColors.surfaceStrong,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Order summary
// ---------------------------------------------------------------------------
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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
            l10n.paymentOrderSummary,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: book.coverUrl != null
                      ? Image.network(
                          resolveCoverUrl(book.coverUrl!) ?? book.coverUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.surfaceStrong,
                          child: const Icon(
                            Icons.menu_book_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (book.authorCompiler != null &&
                        book.authorCompiler!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.authorCompiler!,
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
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpace.sm),
          if (book.isOnSale) ...[
            _SummaryRow(
              label: l10n.paymentPrice,
              value: formatMoney(book.price, book.currency),
              strikeThrough: true,
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: l10n.paymentSalePrice,
              value: formatMoney(book.salePrice!, book.currency),
            ),
            const SizedBox(height: 6),
          ],
          _SummaryRow(
            label: l10n.paymentTotal,
            value: formatMoney(book.finalPrice, book.currency),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.strikeThrough = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool strikeThrough;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 15 : 13,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 13,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? AppColors.primary : AppColors.textSecondary,
            decoration:
                strikeThrough ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — method selection
// ---------------------------------------------------------------------------
class _MethodStep extends ConsumerWidget {
  const _MethodStep({
    required this.book,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onContinue,
  });

  final BookSummary book;
  final PaymentMethodKind? selected;
  final bool busy;
  final ValueChanged<PaymentMethodKind> onSelect;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final methodsAsync = ref.watch(paymentMethodsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderSummary(book: book),
        const SizedBox(height: AppSpace.lg),
        Text(
          l10n.paymentChooseMethod,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        methodsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            l10n.paymentNoMethods,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          data: (result) {
            if (result.methods.isEmpty) {
              return Text(
                l10n.paymentNoMethods,
                style: const TextStyle(color: AppColors.textSecondary),
              );
            }
            return Column(
              children: [
                for (final method in result.methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: _MethodTile(
                      method: method,
                      selected: selected == method,
                      onTap: () => onSelect(method),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.lg),
        FilledButton(
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.paymentContinue),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodKind method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(paymentMethodIcon(method), color: AppColors.primary, size: 24),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                paymentMethodLabel(method, l10n),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — manual bank-transfer details
// ---------------------------------------------------------------------------
class _ManualDetailsStep extends ConsumerWidget {
  const _ManualDetailsStep({
    required this.book,
    required this.selectedBankId,
    required this.receiptName,
    required this.referenceController,
    required this.busy,
    required this.onSelectBank,
    required this.onPickReceipt,
    required this.onSubmit,
  });

  final BookSummary book;
  final String? selectedBankId;
  final String? receiptName;
  final TextEditingController referenceController;
  final bool busy;
  final ValueChanged<String?> onSelectBank;
  final VoidCallback onPickReceipt;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final banksAsync = ref.watch(banksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderSummary(book: book),
        const SizedBox(height: AppSpace.lg),
        Text(
          l10n.paymentTransferInstruction,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          l10n.paymentSelectBank,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        banksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            l10n.paymentErrorGeneric,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          data: (banks) {
            if (banks.isEmpty) {
              return Text(
                l10n.paymentNoBanks,
                style: const TextStyle(color: AppColors.textSecondary),
              );
            }
            BankAccount? selectedBank;
            for (final b in banks) {
              if (b.id == selectedBankId) {
                selectedBank = b;
                break;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedBankId,
                  isExpanded: true,
                  decoration: _inputDecoration(),
                  hint: Text(l10n.paymentSelectBank),
                  items: [
                    for (final bank in banks)
                      DropdownMenuItem(
                        value: bank.id,
                        child: Text(bank.name),
                      ),
                  ],
                  onChanged: onSelectBank,
                ),
                if (selectedBank != null) ...[
                  const SizedBox(height: AppSpace.md),
                  _BankDetailsCard(bank: selectedBank),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          l10n.paymentUploadReceipt,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        _ReceiptDropZone(
          fileName: receiptName,
          onTap: onPickReceipt,
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          l10n.paymentTransactionReference,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        TextField(
          controller: referenceController,
          decoration: _inputDecoration().copyWith(
            hintText: l10n.paymentTransactionReferenceHint,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        FilledButton.icon(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_outline, size: 18),
          label: Text(busy ? l10n.paymentSubmitting : l10n.paymentSubmit),
        ),
      ],
    );
  }
}

class _BankDetailsCard extends StatelessWidget {
  const _BankDetailsCard({required this.bank});

  final BankAccount bank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bank.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _CopyableRow(label: l10n.paymentAccountName, value: bank.accountName),
          const SizedBox(height: 6),
          _CopyableRow(
            label: l10n.paymentAccountNumber,
            value: bank.accountNumber,
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.paymentCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: AppColors.primary,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.paymentCopied)),
            );
          },
        ),
      ],
    );
  }
}

class _ReceiptDropZone extends StatelessWidget {
  const _ReceiptDropZone({required this.fileName, required this.onTap});

  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasFile = fileName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.successSurface
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasFile ? AppColors.successBorder : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasFile
                  ? Icons.check_circle_outline_rounded
                  : Icons.cloud_upload_outlined,
              size: 32,
              color: hasFile ? AppColors.successText : AppColors.primary,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              hasFile ? l10n.paymentReceiptSelected(fileName!) : l10n.paymentReceiptHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: hasFile ? AppColors.successText : AppColors.textSecondary,
              ),
            ),
            if (hasFile) ...[
              const SizedBox(height: 6),
              Text(
                l10n.paymentChangeFile,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — success
// ---------------------------------------------------------------------------
class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.transaction, required this.onDone});

  final PaymentTransaction? transaction;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reference = transaction?.transactionReference ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.xl),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.successText,
          size: 72,
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          l10n.paymentSuccessTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l10n.paymentSuccessMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        if (reference.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              l10n.paymentSuccessReference(reference),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: Text(l10n.paymentDone),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.errorText, size: 20),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceInput,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}
