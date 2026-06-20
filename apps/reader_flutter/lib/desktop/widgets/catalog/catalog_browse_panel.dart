import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../utils/catalog_language_label.dart';
import '../../../widgets/app_state_view.dart';
import '../../../widgets/primitives/shell_primitives.dart';
import 'catalog_grid_delegate.dart';
import 'desktop_book_card.dart';

class DesktopCatalogBrowsePanel extends ConsumerStatefulWidget {
  const DesktopCatalogBrowsePanel({
    super.key,
    required this.books,
    required this.onRefresh,
    required this.padding,
    this.header,
    this.searchQuery = '',
    this.bottomPadding = 16,
  });

  final List<BookSummary> books;
  final Future<void> Function() onRefresh;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final String searchQuery;
  final double bottomPadding;

  @override
  ConsumerState<DesktopCatalogBrowsePanel> createState() =>
      _DesktopCatalogBrowsePanelState();
}

class _DesktopCatalogBrowsePanelState
    extends ConsumerState<DesktopCatalogBrowsePanel> {
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

  Widget _filterRow(AppLocalizations l10n, List<String> languageKeys) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
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
        const SizedBox(width: 12),
        AppSegmentedControl<bool>(
          options: [
            AppSegmentedOption(value: false, label: l10n.libraryViewList),
            AppSegmentedOption(value: true, label: l10n.libraryViewGrid),
          ],
          value: _gridView,
          onChanged: (v) => setState(() => _gridView = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageKeys = _languageKeys(l10n);
    final filtered = _filtered(l10n);
    final sorted = [...filtered]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final insets = widget.padding.resolve(Directionality.of(context));

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                insets.left,
                insets.top,
                insets.right,
                0,
              ),
              sliver: SliverToBoxAdapter(child: widget.header),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(insets.left, 0, insets.right, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filterRow(l10n, languageKeys),
                  const SizedBox(height: 6),
                  Text(
                    l10n.booksAvailable(sorted.length),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (sorted.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppStateView(
                title: l10n.noMatchingBooksTitle,
                message: l10n.noMatchingBooksMessage,
                icon: Icons.search_off_rounded,
              ),
            )
          else if (_gridView)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                insets.left,
                0,
                insets.right,
                widget.bottomPadding,
              ),
              sliver: SliverGrid(
                gridDelegate: desktopCatalogGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => DesktopBookCard(
                    book: sorted[index],
                    index: index,
                  ),
                  childCount: sorted.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                insets.left,
                0,
                insets.right,
                insets.bottom,
              ),
              sliver: SliverList.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) => DesktopBookListRow(
                  book: sorted[index],
                  index: index,
                ),
              ),
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
