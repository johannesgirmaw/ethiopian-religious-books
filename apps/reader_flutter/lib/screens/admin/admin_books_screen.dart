import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/app_state_view.dart';

class AdminBooksScreen extends ConsumerStatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  ConsumerState<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends ConsumerState<AdminBooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _visibility = 'all';
  String _sort = 'updated';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ref = this.ref;
    final async = ref.watch(adminBooksProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.adminBooksListTitle),
        actions: [
          IconButton(
            tooltip: l10n.newBookTooltip,
            onPressed: () => context.push('/admin/books/new'),
            icon: const Icon(Icons.add),
          ),
        ],
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
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: l10n.searchBooksLabel,
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
                    onChanged: (value) => setState(
                      () => _query = value.trim().toLowerCase(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
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
                        onSelected: (_) =>
                            setState(() => _visibility = 'hidden'),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sort,
                        items: [
                          DropdownMenuItem(
                            value: 'updated',
                            child: Text(l10n.sortRecent),
                          ),
                          DropdownMenuItem(
                            value: 'title',
                            child: Text(l10n.sortTitle),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(l10n.noBooksMatchFilters)),
                  )
                else
                  ...filtered.map(
                    (b) => Column(
                      children: [
                        _AdminBookTile(book: b),
                        const Divider(height: 1),
                      ],
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
    if (_sort == 'title') {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return filtered;
  }
}

class _AdminBookTile extends StatelessWidget {
  const _AdminBookTile({required this.book});

  final AdminBook book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vis = book.catalogVisibility;
    final chipColor =
        book.isPublished ? Colors.green.shade100 : Colors.orange.shade100;
    final statusLabel =
        book.isPublished ? l10n.publishedStatus : l10n.draftStatus;
    final statusIcon = book.isPublished
        ? Icons.verified_rounded
        : Icons.edit_note_outlined;
    return ListTile(
      title: Text(book.title),
      subtitle: Text(
        [
          if (book.authorCompiler != null && book.authorCompiler!.isNotEmpty)
            book.authorCompiler!,
          l10n.visibilityLabel(vis),
          l10n.statusLabel(statusLabel),
        ].join(' · '),
      ),
      trailing: Chip(
        avatar: Icon(statusIcon, size: 14),
        label: Text(
          l10n.statusChip(statusLabel, vis),
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: chipColor,
        padding: EdgeInsets.zero,
      ),
      onTap: () => context.push('/admin/books/${book.id}', extra: book),
    );
  }
}
