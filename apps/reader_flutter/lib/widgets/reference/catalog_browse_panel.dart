import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../utils/catalog_language_label.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shell_primitives.dart';
import '../../widgets/reference/catalog_book_tile.dart';
import '../../widgets/reference/catalog_browse_header.dart';
import '../../widgets/reference/language_filter_chips.dart';

class CatalogBrowsePanel extends ConsumerStatefulWidget {
  const CatalogBrowsePanel({
    super.key,
    required this.books,
    required this.onRefresh,
    this.bottomPadding = 16,
  });

  final List<BookSummary> books;
  final Future<void> Function() onRefresh;
  final double bottomPadding;

  @override
  ConsumerState<CatalogBrowsePanel> createState() =>
      _CatalogBrowsePanelState();
}

class _CatalogBrowsePanelState extends ConsumerState<CatalogBrowsePanel> {
  String _query = '';
  String? _selectedLanguage;
  bool _gridView = true;

  List<LanguageFilterOption> _languageOptions(AppLocalizations l10n) {
    final keys = <String>{};
    final options = <LanguageFilterOption>[];
    for (final book in widget.books) {
      final key = catalogLanguageFilterKey(book.primaryLanguage, l10n);
      if (keys.add(key)) {
        options.add(
          LanguageFilterOption(
            key: key,
            label: catalogLanguageFilterLabel(book.primaryLanguage, l10n),
          ),
        );
      }
    }
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<BookSummary> _applyFilters(AppLocalizations l10n) {
    final q = _query.trim().toLowerCase();
    return widget.books.where((book) {
      final langKey = catalogLanguageFilterKey(book.primaryLanguage, l10n);
      if (_selectedLanguage != null && langKey != _selectedLanguage) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        book.title,
        book.authorCompiler ?? '',
        book.summary ?? '',
        book.subtitle ?? '',
        catalogLanguageFilterLabel(book.primaryLanguage, l10n),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageOptions = _languageOptions(l10n);
    final filteredBooks = _applyFilters(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CatalogBrowseHeader(
          categoryLabel: l10n.headerCategoriesStat(languageOptions.length),
          bookLabel: l10n.headerBooksStat(filteredBooks.length),
          searchHint: l10n.librarySearchHint,
          initialQuery: _query,
          onSearchChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: 12),
        LanguageFilterChips(
          options: languageOptions,
          selectedKey: _selectedLanguage,
          onSelected: (lang) => setState(() => _selectedLanguage = lang),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.booksAvailable(filteredBooks.length),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AppSegmentedControl<bool>(
                options: [
                  AppSegmentedOption(
                    value: false,
                    label: l10n.libraryViewList,
                  ),
                  AppSegmentedOption(
                    value: true,
                    label: l10n.libraryViewGrid,
                  ),
                ],
                value: _gridView,
                onChanged: (v) => setState(() => _gridView = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: widget.onRefresh,
            child: _buildBookList(l10n, filteredBooks),
          ),
        ),
      ],
    );
  }

  Widget _buildBookList(AppLocalizations l10n, List<BookSummary> books) {
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

    final listView = ListView.builder(
      key: const ValueKey('list'),
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => CatalogBookListTile(
        book: sorted[index],
        index: index,
      ),
    );

    final gridView = GridView.builder(
      key: const ValueKey('grid'),
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
        childAspectRatio: 0.76,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => CatalogBookGridTile(
        book: sorted[index],
        index: index,
      ),
    );

    return AnimatedSwitcher(
      duration: AppMotion.short,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _gridView ? gridView : listView,
    );
  }
}
