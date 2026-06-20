import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../utils/catalog_language_label.dart';
import '../../../widgets/app_state_view.dart';
import '../../../widgets/primitives/shell_primitives.dart';
import '../../layout/app_layout_scope.dart';
import 'catalog_grid_delegate.dart';
import 'web_book_card.dart';

class WebCatalogBrowsePanel extends ConsumerStatefulWidget {
  const WebCatalogBrowsePanel({
    super.key,
    required this.books,
    required this.onRefresh,
    this.searchQuery = '',
    this.bottomPadding = 16,
  });

  final List<BookSummary> books;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final double bottomPadding;

  @override
  ConsumerState<WebCatalogBrowsePanel> createState() =>
      _WebCatalogBrowsePanelState();
}

class _WebCatalogBrowsePanelState extends ConsumerState<WebCatalogBrowsePanel> {
  String? _selectedLanguage;
  bool _gridView = true;

  List<String> _languageKeys(AppLocalizations l10n) {
    final keys = <String>{};
    for (final book in widget.books) {
      keys.add(catalogLanguageFilterKey(book.primaryLanguage, l10n));
    }
    final list = keys.toList()..sort();
    return list;
  }

  String _languageLabel(String key, AppLocalizations l10n) {
    for (final book in widget.books) {
      if (catalogLanguageFilterKey(book.primaryLanguage, l10n) == key) {
        return catalogLanguageFilterLabel(book.primaryLanguage, l10n);
      }
    }
    return key;
  }

  List<BookSummary> _filtered(AppLocalizations l10n) {
    final q = widget.searchQuery.trim().toLowerCase();
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
    final languageKeys = _languageKeys(l10n);
    final filtered = _filtered(l10n);
    final sorted = [...filtered]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.filterAll,
                    selected: _selectedLanguage == null,
                    onTap: () => setState(() => _selectedLanguage = null),
                  ),
                  for (final key in languageKeys)
                    _FilterChip(
                      label: _languageLabel(key, l10n),
                      selected: _selectedLanguage == key,
                      onTap: () => setState(() => _selectedLanguage = key),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            AppSegmentedControl<bool>(
              options: [
                AppSegmentedOption(value: false, label: l10n.libraryViewList),
                AppSegmentedOption(value: true, label: l10n.libraryViewGrid),
              ],
              value: _gridView,
              onChanged: (v) => setState(() => _gridView = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.booksAvailable(sorted.length),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: widget.onRefresh,
            child: _buildList(context, l10n, sorted),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<BookSummary> sorted,
  ) {
    if (sorted.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppStateView(
            title: l10n.noMatchingBooksTitle,
            message: l10n.noMatchingBooksMessage,
            icon: Icons.search_off_rounded,
          ),
        ],
      );
    }

    if (_gridView) {
      return GridView.builder(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: catalogGridDelegate(context),
        itemCount: sorted.length,
        itemBuilder: (context, index) => WebBookCard(
          book: sorted[index],
          index: index,
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => WebBookListRow(
        book: sorted[index],
        index: index,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.referencePrimary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.referencePrimary : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
