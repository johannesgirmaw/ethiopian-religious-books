import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/author_application.dart';
import '../../providers/author_application_api.dart';
import '../../utils/api_error_message.dart';
import '../app_state_view.dart';
import '../primitives/shell_primitives.dart';
import 'author_page_header.dart';

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

(String, AppStatusKind) _statusChip(AuthorApplication app, AppLocalizations l10n) {
  if (app.isApproved) {
    return (l10n.adminAuthorAppStatusApproved, AppStatusKind.active);
  }
  if (app.isRejected) {
    return (l10n.adminAuthorAppStatusRejected, AppStatusKind.neutral);
  }
  return (l10n.adminAuthorAppStatusPending, AppStatusKind.pending);
}

/// Admin review queue for author applications. Shared across platforms; each
/// route adapter wraps it in a scaffold. Mirrors the orders/payments admin view.
class AdminAuthorApplicationsView extends ConsumerStatefulWidget {
  const AdminAuthorApplicationsView({super.key, this.showHeader = false});

  final bool showHeader;

  @override
  ConsumerState<AdminAuthorApplicationsView> createState() =>
      _AdminAuthorApplicationsViewState();
}

class _AdminAuthorApplicationsViewState
    extends ConsumerState<AdminAuthorApplicationsView> {
  // '' = all, or 'pending' / 'approved' / 'rejected'.
  String _filter = 'pending';

  static const _filters = <String>['', 'pending', 'approved', 'rejected'];

  String _filterLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'pending':
        return l10n.adminAuthorAppStatusPending;
      case 'approved':
        return l10n.adminAuthorAppStatusApproved;
      case 'rejected':
        return l10n.adminAuthorAppStatusRejected;
      default:
        return l10n.adminOrdersAllStatuses;
    }
  }

  List<AuthorApplication> _apply(List<AuthorApplication> src) {
    if (_filter.isEmpty) return src;
    return src.where((a) => a.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _buildContent(l10n);
    if (!widget.showHeader) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthorPageHeader(
          title: l10n.adminAuthorAppsTitle,
          subtitle: l10n.adminAuthorAppsSubtitle,
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final async = ref.watch(adminAuthorApplicationsProvider);

    Widget scrollable(List<Widget> children) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminAuthorApplicationsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: children,
          ),
        );

    List<Widget> controls(int pending) => [
          _PendingStat(count: pending, l10n: l10n),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text(_filterLabel(f, l10n)),
                  selected: _filter == f,
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _filter == f ? AppColors.primary : AppColors.border,
                  ),
                  backgroundColor: AppColors.surfaceCard,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _filter == f
                        ? AppColors.primaryDeep
                        : AppColors.textSecondary,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
        ];

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => scrollable([
        AppStateView(
          title: l10n.adminAuthorAppsTitle,
          message: '$e',
          icon: Icons.how_to_reg_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(adminAuthorApplicationsProvider),
        ),
      ]),
      data: (page) {
        final items = _apply(page.items);
        if (items.isEmpty) {
          return scrollable([
            ...controls(page.pending),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  page.items.isEmpty
                      ? l10n.adminAuthorAppsEmpty
                      : l10n.adminAuthorAppsNoMatch,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ]);
        }
        return scrollable([
          ...controls(page.pending),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  for (final app in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ApplicationCard(
                        app: app,
                        l10n: l10n,
                        onTap: () => _openReview(app),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _openReview(AuthorApplication app) async {
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
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            child: _ReviewSheet(app: app),
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
      builder: (_) => _ReviewSheet(app: app),
    );
  }
}

class _PendingStat extends StatelessWidget {
  const _PendingStat({required this.count, required this.l10n});

  final int count;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_reg_outlined,
              size: 22, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.adminAuthorAppPendingReviews,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.app,
    required this.l10n,
    required this.onTap,
  });

  final AuthorApplication app;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, kind) = _statusChip(app, l10n);
    final name = app.fullName.trim().isEmpty
        ? l10n.adminAuthorAppUnnamed
        : app.fullName.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.listRow,
        ),
        child: Row(
          children: [
            _Thumb(url: app.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (app.title.trim().isNotEmpty) app.title.trim(),
                      if (app.userEmail != null && app.userEmail!.isNotEmpty)
                        app.userEmail!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AppStatusChip(label: label, kind: kind),
                      const Spacer(),
                      Text(
                        _formatDate(app.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url.isEmpty
            ? _placeholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: AppColors.surfaceInput,
        child: Icon(Icons.person_outline_rounded,
            size: 24, color: AppColors.textTertiary),
      );
}

// ---------------------------------------------------------------------------
// Review sheet (approve / reject)
// ---------------------------------------------------------------------------
class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.app});

  final AuthorApplication app;

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
    final navigator = Navigator.of(context);

    if (approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.adminAuthorAppApproveConfirm),
          content: Text(
            l10n.adminAuthorAppApproveConfirmBody,
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
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(authorApplicationApiProvider);
      if (approve) {
        await api.approve(widget.app.id);
      } else {
        await api.reject(widget.app.id, note: _note.text.trim());
      }
      ref.invalidate(adminAuthorApplicationsProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? l10n.adminApproved : l10n.adminRejected),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = messageFromDioResponse(e.response?.data) ??
          e.message ??
          '$e');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = widget.app;
    final canAct = !app.isApproved;

    final detail = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: app.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.fullName.trim().isEmpty
                          ? l10n.adminAuthorAppUnnamed
                          : app.fullName.trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (app.userEmail != null && app.userEmail!.isNotEmpty)
                      Text(
                        app.userEmail!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              () {
                final (label, kind) = _statusChip(app, l10n);
                return AppStatusChip(label: label, kind: kind);
              }(),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _DetailRow(label: l10n.authorFieldPenName, value: app.penName),
          _DetailRow(label: l10n.authorFieldTitle, value: app.title),
          _DetailRow(label: l10n.authorFieldBio, value: app.bio),
          _DetailRow(label: l10n.authorFieldPhone, value: app.phone),
          _DetailRow(label: l10n.authorFieldCountry, value: app.country),
          _DetailRow(
              label: l10n.authorFieldCredentials, value: app.credentials),
          _DetailRow(
              label: l10n.authorFieldSampleLinks, value: app.sampleLinks),
          _DetailRow(
              label: l10n.authorFieldPaymentEmail, value: app.paymentEmail),
          _DetailRow(label: l10n.authorFieldTelebirr, value: app.telebirrNumber),
          if (app.isRejected && app.reviewNote.trim().isNotEmpty)
            _DetailRow(
                label: l10n.authorApplyReviewNoteLabel, value: app.reviewNote),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: detail),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _footer(l10n, canAct: canAct),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(AppLocalizations l10n, {required bool canAct}) {
    final children = <Widget>[];
    if (_error != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(
          _error!,
          style: const TextStyle(color: AppColors.errorText, fontSize: 13),
        ),
      ));
    }
    if (!canAct) {
      children.add(SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ));
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }

    children.add(TextField(
      controller: _note,
      minLines: 1,
      maxLines: 3,
      style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.adminRejectReason,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ));
    children.add(const SizedBox(height: AppSpace.md));
    children.add(Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _act(approve: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText,
              side: const BorderSide(color: AppColors.errorBorder),
              minimumSize: const Size(0, 48),
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
              minimumSize: const Size(0, 48),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.adminApprove),
          ),
        ),
      ],
    ));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
