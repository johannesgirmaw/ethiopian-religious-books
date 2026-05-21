import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../widgets/app_state_view.dart';
import '../widgets/reference/book_expansion_card.dart';
import '../widgets/reference/language_filter_chips.dart';
import '../widgets/reference/page_header_box.dart';
import '../widgets/skeleton_loader.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  String? _selectedLanguage;

  List<String> _languageLabels(List<BookSummary> books, AppLocalizations l10n) {
    final set = <String>{};
    for (final b in books) {
      final key = (b.primaryLanguage ?? '').trim().isEmpty
          ? l10n.generalCategory
          : b.primaryLanguage!.trim();
      set.add(key);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      body: async.when(
        data: (page) {
          final languages = _languageLabels(page.items, l10n);
          final filteredBooks = _applyFilters(page.items, l10n);

          if (page.items.isEmpty) {
            return Column(
              children: [
                PageHeaderBox(
                  title: l10n.drawerBrowse,
                  categoryLabel: l10n.headerCategoriesStat(0),
                  bookLabel: l10n.headerBooksStat(0),
                  searchHint: l10n.librarySearchHint,
                  onSearchChanged: (q) => setState(() => _query = q),
                  initialQuery: _query,
                ),
                Expanded(
                  child: AppStateView(
                    title: l10n.libraryEmptyTitle,
                    message: l10n.libraryEmptyMessage,
                    icon: Icons.library_books_outlined,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              PageHeaderBox(
                title: l10n.drawerBrowse,
                categoryLabel: l10n.headerCategoriesStat(languages.length),
                bookLabel: l10n.headerBooksStat(filteredBooks.length),
                searchHint: l10n.librarySearchHint,
                onSearchChanged: (q) => setState(() => _query = q),
                initialQuery: _query,
              ),
              const SizedBox(height: 8),
              LanguageFilterChips(
                languages: languages,
                selectedLanguage: _selectedLanguage,
                onSelected: (lang) => setState(() => _selectedLanguage = lang),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(catalogProvider);
                    await ref.read(catalogProvider.future);
                  },
                  child: _buildBookList(context, l10n, filteredBooks),
                ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            PageHeaderBox(
              title: l10n.drawerBrowse,
              categoryLabel: '…',
              bookLabel: '…',
              searchHint: l10n.librarySearchHint,
            ),
            const Expanded(child: SkeletonCardGroup(count: 4)),
          ],
        ),
        error: (e, _) => Column(
          children: [
            PageHeaderBox(
              title: l10n.drawerBrowse,
              categoryLabel: l10n.headerCategoriesStat(0),
              bookLabel: l10n.headerBooksStat(0),
              searchHint: l10n.librarySearchHint,
            ),
            Expanded(
              child: AppStateView(
                title: l10n.unableToLoadLibrary,
                message: '$e',
                icon: Icons.cloud_off_outlined,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(catalogProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(
    BuildContext context,
    AppLocalizations l10n,
    List<BookSummary> books,
  ) {
    if (books.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AppStateView(
              title: l10n.noMatchingBooksTitle,
              message: l10n.noMatchingBooksMessage,
              icon: Icons.search_off_rounded,
            ),
          ),
        ],
      );
    }

    final sorted = [...books]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return BookExpansionCard(book: sorted[index], index: index);
      },
    );
  }

  String _bookLanguageKey(BookSummary book, AppLocalizations l10n) {
    return (book.primaryLanguage ?? '').trim().isEmpty
        ? l10n.generalCategory
        : book.primaryLanguage!.trim();
  }

  List<BookSummary> _applyFilters(List<BookSummary> books, AppLocalizations l10n) {
    final q = _query.trim().toLowerCase();
    return books.where((book) {
      if (_selectedLanguage != null &&
          _bookLanguageKey(book, l10n) != _selectedLanguage) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        book.title,
        book.authorCompiler ?? '',
        book.summary ?? '',
        book.subtitle ?? '',
        _bookLanguageKey(book, l10n),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
}
