import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/session_notifier.dart';
import '../../common/platform/platform_shell.dart';
import '../../desktop/screens/admin_books_screen_body.dart';
import '../../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/screens/admin_books_screen_body.dart';
import '../../web/widgets/shell/web_page_scaffold.dart';
import '../../widgets/admin_book_status_chip.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shell_primitives.dart';
import 'admin_book_actions.dart';
import 'admin_book_import.dart';

/// Single admin hub: search, filter, and manage every book from one list.
class AdminBooksScreen extends ConsumerStatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  ConsumerState<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends ConsumerState<AdminBooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _visibility = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (useWebShell(context)) {
      return const WebPageScaffold(body: AdminBooksScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopAdminBooksScreenBody());
    }

    final async = ref.watch(adminBooksProvider);
    final isAdmin =
        ref.watch(sessionNotifierProvider).valueOrNull?.user?.isPlatformAdmin ??
            false;

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(isAdmin ? l10n.adminBooksListTitle : l10n.authorMyBooks),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: l10n.adminPaymentsTitle,
              onPressed: () => context.push('/admin/payments'),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          IconButton(
            tooltip: l10n.importFromWord,
            onPressed: () =>
                importBookFromDocxFlow(context: context, ref: ref),
            icon: const Icon(Icons.upload_file_rounded),
          ),
          IconButton(
            tooltip: l10n.newBookTooltip,
            onPressed: () => context.push('/admin/books/new'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/books/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createFirstBook),
      ),
      body: async.when(
        data: (page) {
          final filtered = _applyFilters(page.items);
          if (page.items.isEmpty) {
            return AppStateView(
              title: l10n.noBooksYetTitle,
              message: l10n.noBooksYetMessage,
              icon: Icons.post_add_outlined,
              actionLabel: l10n.createFirstBook,
              onAction: () => context.push('/admin/books/new'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminBooksProvider);
              await ref.read(adminBooksProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchBooksHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.filterAll),
                      selected: _visibility == 'all',
                      onSelected: (_) => setState(() => _visibility = 'all'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.filterPublished),
                      selected: _visibility == 'published',
                      onSelected: (_) =>
                          setState(() => _visibility = 'published'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.filterHidden),
                      selected: _visibility == 'hidden',
                      onSelected: (_) => setState(() => _visibility = 'hidden'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.adminBooksCount(filtered.length, page.items.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(l10n.noBooksMatchFilters)),
                  )
                else
                  ...filtered.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminBookCard(book: b),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: l10n.unableToLoadBooks,
          message: '$e',
          icon: Icons.cloud_off_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(adminBooksProvider),
        ),
      ),
    );
  }

  List<AdminBook> _applyFilters(List<AdminBook> books) {
    final filtered = books.where((book) {
      if (_visibility != 'all' && book.catalogVisibility != _visibility) {
        return false;
      }
      if (_query.isEmpty) return true;
      final haystack = [
        book.title,
        book.authorCompiler ?? '',
        book.primaryLanguage,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
    filtered.sort(
      (a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''),
    );
    return filtered;
  }
}

class _AdminBookCard extends ConsumerStatefulWidget {
  const _AdminBookCard({required this.book});

  final AdminBook book;

  @override
  ConsumerState<_AdminBookCard> createState() => _AdminBookCardState();
}

enum _AdminBookMenuAction {
  edit,
  submitReview,
  withdrawReview,
  approveReview,
  requestChanges,
  viewFeedback,
  publish,
  unpublish,
  openReader,
}

class _AdminBookCardState extends ConsumerState<_AdminBookCard> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  bool _canEditBook(AdminBook book, String? currentUserId) =>
      !book.isPublished && !book.isInReview && book.isCreatedBy(currentUserId);

  void _openReview() {
    context.push('/admin/books/${widget.book.id}/review');
  }

  void _openEdit() {
    final currentUserId =
        ref.read(sessionNotifierProvider).valueOrNull?.user?.id;
    if (!_canEditBook(widget.book, currentUserId)) return;
    context.push('/admin/books/${widget.book.id}/edit', extra: widget.book);
  }

  void _openDetail() {
    context.push('/book/${widget.book.id}');
  }

  Future<void> _onMenuAction(_AdminBookMenuAction action) async {
    final book = widget.book;
    switch (action) {
      case _AdminBookMenuAction.edit:
        _openEdit();
      case _AdminBookMenuAction.submitReview:
        await _run(() => adminSubmitBookForReview(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.withdrawReview:
        await _run(() => adminWithdrawBookReview(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.approveReview:
        await _run(() => adminApproveBookReview(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.requestChanges:
        await _run(() => adminRequestChangesForBook(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.viewFeedback:
        _openReview();
      case _AdminBookMenuAction.publish:
        await _run(() => adminPublishBook(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.unpublish:
        await _run(() => adminUnpublishBook(
              context: context,
              ref: ref,
              bookId: book.id,
            ));
      case _AdminBookMenuAction.openReader:
        context.push('/book/${book.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final book = widget.book;
    final theme = Theme.of(context);
    final isPublished = book.isPublished;
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    final currentUserId = user?.id;
    final isReviewer = user?.isPlatformAdmin ?? false;
    final isCreator = book.isCreatedBy(currentUserId);
    final canEdit = !isPublished && !book.isInReview && isCreator;
    final canUnpublish = isPublished && isCreator;
    final canSubmitReview = isCreator && !isPublished && book.isDraftReview;
    final canWithdraw = isCreator && book.isInReview;
    final canReview = isReviewer && book.isInReview;
    final canPublish = isCreator && !isPublished && book.isReviewed;
    final chapterCount = book.chaptersDraft.length;
    final pageCount = book.chaptersDraft.fold<int>(
      0,
      (sum, c) => sum + c.pages.length,
    );

    final (statusLabel, statusKind) = adminBookStatusChip(l10n, book.displayStatus);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        onTap: _busy
            ? null
            : canEdit
                ? _openEdit
                : isPublished
                    ? _openDetail
                    : null,
        child: AppPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (book.authorCompiler != null &&
                            book.authorCompiler!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            book.authorCompiler!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppStatusChip(label: statusLabel, kind: statusKind),
                  _busy
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : PopupMenuButton<_AdminBookMenuAction>(
                          tooltip: l10n.adminBookActionsTooltip,
                          icon: const Icon(Icons.more_vert_rounded),
                          padding: EdgeInsets.zero,
                          onSelected: _onMenuAction,
                          itemBuilder: (context) => [
                            if (canEdit)
                              _menuItem(
                                value: _AdminBookMenuAction.edit,
                                icon: Icons.edit_outlined,
                                label: l10n.adminEditAction,
                              ),
                            if (canSubmitReview)
                              _menuItem(
                                value: _AdminBookMenuAction.submitReview,
                                icon: Icons.reviews_outlined,
                                label: l10n.sendForReview,
                              ),
                            if (canWithdraw)
                              _menuItem(
                                value: _AdminBookMenuAction.withdrawReview,
                                icon: Icons.undo_outlined,
                                label: l10n.withdrawFromReview,
                              ),
                            if (canReview)
                              _menuItem(
                                value: _AdminBookMenuAction.approveReview,
                                icon: Icons.check_circle_outline,
                                label: l10n.approveReview,
                              ),
                            if (canReview)
                              _menuItem(
                                value: _AdminBookMenuAction.requestChanges,
                                icon: Icons.rate_review_outlined,
                                label: l10n.requestChanges,
                              ),
                            if (book.hasPendingChangeRequest)
                              _menuItem(
                                value: _AdminBookMenuAction.viewFeedback,
                                icon: Icons.feedback_outlined,
                                label: l10n.viewReviewFeedback,
                              ),
                            if (canPublish)
                              _menuItem(
                                value: _AdminBookMenuAction.publish,
                                icon: Icons.publish_outlined,
                                label: l10n.publish,
                              ),
                            if (canUnpublish)
                              _menuItem(
                                value: _AdminBookMenuAction.unpublish,
                                icon: Icons.visibility_off_outlined,
                                label: l10n.unpublish,
                              ),
                            if (isPublished)
                              _menuItem(
                                value: _AdminBookMenuAction.openReader,
                                icon: Icons.menu_book_outlined,
                                label: l10n.openInReader,
                              ),
                          ],
                        ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  l10n.visibilityLabel(book.catalogVisibility),
                  book.primaryLanguage,
                  if (chapterCount > 0)
                    l10n.draftChapterPageCounts(chapterCount, pageCount),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_AdminBookMenuAction> _menuItem({
    required _AdminBookMenuAction value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
