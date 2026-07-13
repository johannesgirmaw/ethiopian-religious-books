import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/session_notifier.dart';
import '../../screens/admin/admin_book_actions.dart';
import '../../screens/admin/admin_book_import.dart';
import '../../widgets/admin_book_status_chip.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shell_primitives.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_scroll_body.dart';
import '../widgets/common/desktop_section.dart';

class DesktopAdminBooksScreenBody extends ConsumerStatefulWidget {
  const DesktopAdminBooksScreenBody({super.key});

  @override
  ConsumerState<DesktopAdminBooksScreenBody> createState() =>
      _DesktopAdminBooksScreenBodyState();
}

class _DesktopAdminBooksScreenBodyState
    extends ConsumerState<DesktopAdminBooksScreenBody> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _visibility = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    filtered.sort((a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(adminBooksProvider);
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));

    Widget searchAndFilters() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopSearchField(
            controller: _searchController,
            hintText: l10n.searchBooksHint,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            width: double.infinity,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterChip(
                label: l10n.filterAll,
                selected: _visibility == 'all',
                onTap: () => setState(() => _visibility = 'all'),
              ),
              _FilterChip(
                label: l10n.filterPublished,
                selected: _visibility == 'published',
                onTap: () => setState(() => _visibility = 'published'),
              ),
              _FilterChip(
                label: l10n.filterHidden,
                selected: _visibility == 'hidden',
                onTap: () => setState(() => _visibility = 'hidden'),
              ),
            ],
          ),
        ],
      );
    }

    return async.when(
      data: (page) {
        final filtered = _applyFilters(page.items);
        return DesktopScrollBody(
          padding: padding,
          children: [
            DesktopPageHeader(
              title: l10n.adminBooksListTitle,
              subtitle:
                  l10n.adminBooksCount(filtered.length, page.items.length),
              actions: [
                OutlinedButton.icon(
                  onPressed: () =>
                      importBookFromDocxFlow(context: context, ref: ref),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(l10n.importFromWord),
                ),
                FilledButton.icon(
                  onPressed: () => context.push('/admin/books/new'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.createFirstBook),
                ),
              ],
              bottom: searchAndFilters(),
            ),
            const SizedBox(height: 24),
            if (page.items.isEmpty)
              DesktopEmptyState(
                icon: Icons.post_add_outlined,
                title: l10n.noBooksYetTitle,
                message: l10n.noBooksYetMessage,
                action: FilledButton.icon(
                  onPressed: () => context.push('/admin/books/new'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.createFirstBook),
                ),
              )
            else if (filtered.isEmpty)
              DesktopEmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.noBooksMatchFilters,
                message: l10n.noBooksMatchFilters,
              )
            else
              DesktopSection(
                title: l10n.adminBooksListTitle.toUpperCase(),
                child: DesktopPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _AdminBookRow(book: filtered[i]),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => DesktopScrollBody(
        padding: padding,
        children: [
          DesktopPageHeader(title: l10n.adminBooksListTitle),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (e, _) => DesktopScrollBody(
        padding: padding,
        children: [
          DesktopPageHeader(title: l10n.adminBooksListTitle),
          const SizedBox(height: 24),
          AppStateView(
            title: l10n.unableToLoadBooks,
            message: '$e',
            icon: Icons.cloud_off_outlined,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(adminBooksProvider),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.referencePrimary
                  : _hovered
                      ? AppColors.surfaceStrong
                      : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.selected
                    ? AppColors.referencePrimary
                    : AppColors.line,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBookRow extends ConsumerStatefulWidget {
  const _AdminBookRow({required this.book});

  final AdminBook book;

  @override
  ConsumerState<_AdminBookRow> createState() => _AdminBookRowState();
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

class _AdminBookRowState extends ConsumerState<_AdminBookRow> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final book = widget.book;
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
    final (statusLabel, statusKind) =
        adminBookStatusChip(l10n, book.displayStatus);
    final chapterCount = book.chaptersDraft.length;
    final pageCount =
        book.chaptersDraft.fold<int>(0, (sum, c) => sum + c.pages.length);

    return InkWell(
      onTap: _busy
          ? null
          : canEdit
              ? () => context.push('/admin/books/${book.id}/edit', extra: book)
              : isPublished
                  ? () => context.push('/book/${book.id}')
                  : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (book.authorCompiler?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      book.authorCompiler!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      l10n.visibilityLabel(book.catalogVisibility),
                      book.primaryLanguage,
                      if (chapterCount > 0)
                        l10n.draftChapterPageCounts(chapterCount, pageCount),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AppStatusChip(label: statusLabel, kind: statusKind),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<_AdminBookMenuAction>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) async {
                  switch (action) {
                    case _AdminBookMenuAction.edit:
                      if (canEdit) {
                        context.push('/admin/books/${book.id}/edit', extra: book);
                      }
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
                      context.push('/admin/books/${book.id}/review');
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
                },
                itemBuilder: (context) => [
                  if (canEdit)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.edit,
                      child: Text(l10n.adminEditAction),
                    ),
                  if (canSubmitReview)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.submitReview,
                      child: Text(l10n.sendForReview),
                    ),
                  if (canWithdraw)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.withdrawReview,
                      child: Text(l10n.withdrawFromReview),
                    ),
                  if (canReview)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.approveReview,
                      child: Text(l10n.approveReview),
                    ),
                  if (canReview)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.requestChanges,
                      child: Text(l10n.requestChanges),
                    ),
                  if (book.hasPendingChangeRequest)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.viewFeedback,
                      child: Text(l10n.viewReviewFeedback),
                    ),
                  if (canPublish)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.publish,
                      child: Text(l10n.publish),
                    ),
                  if (canUnpublish)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.unpublish,
                      child: Text(l10n.unpublish),
                    ),
                  if (isPublished)
                    PopupMenuItem(
                      value: _AdminBookMenuAction.openReader,
                      child: Text(l10n.openInReader),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
