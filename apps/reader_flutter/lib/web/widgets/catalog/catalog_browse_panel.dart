import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/book_models.dart';
import '../../../providers/catalog_providers.dart';
import '../../../utils/catalog_language_label.dart';
import '../../../widgets/app_state_view.dart';
import '../../../widgets/primitives/shell_primitives.dart';
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
  String? _selectedGenre;
  String? _selectedLanguage;
  bool _gridView = true;

  List<String> _languageKeys(AppLocalizations l10n) {
    final keys = <String>{
      for (final b in widget.books)
        catalogLanguageFilterKey(b.primaryLanguage, l10n),
    };
    return keys.toList()..sort();
  }

  String _languageLabel(String key, AppLocalizations l10n) {
    for (final b in widget.books) {
      if (catalogLanguageFilterKey(b.primaryLanguage, l10n) == key) {
        return catalogLanguageFilterLabel(b.primaryLanguage, l10n);
      }
    }
    return key;
  }

  List<GenreOption> _genreOptions() {
    final lookup =
        ref.watch(genresProvider).valueOrNull ?? const <GenreOption>[];
    final present = <String>{
      for (final b in widget.books) (b.genre ?? '').trim(),
    }..removeWhere((s) => s.isEmpty);
    final bySlug = {for (final g in lookup) g.slug: g};
    final options = <GenreOption>[
      for (final g in lookup)
        if (present.contains(g.slug)) g,
    ];
    for (final s in present) {
      if (!bySlug.containsKey(s)) options.add(GenreOption(slug: s, label: s));
    }
    return options;
  }

  String _genreLabel(BuildContext context, GenreOption g) {
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    if (isAm && (g.labelAm?.isNotEmpty ?? false)) return g.labelAm!;
    return g.label.isNotEmpty ? g.label : g.slug;
  }

  List<BookSummary> _filtered(AppLocalizations l10n) {
    final q = widget.searchQuery.trim().toLowerCase();
    return widget.books.where((book) {
      if (_selectedGenre != null &&
          (book.genre ?? '').trim() != _selectedGenre) {
        return false;
      }
      if (_selectedLanguage != null &&
          catalogLanguageFilterKey(book.primaryLanguage, l10n) !=
              _selectedLanguage) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        book.title,
        book.authorCompiler ?? '',
        book.summary ?? '',
        book.subtitle ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final genreOptions = _genreOptions();
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
                    selected: _selectedGenre == null,
                    onTap: () => setState(() => _selectedGenre = null),
                  ),
                  for (final g in genreOptions)
                    _FilterChip(
                      label: _genreLabel(context, g),
                      selected: _selectedGenre == g.slug,
                      onTap: () => setState(() => _selectedGenre = g.slug),
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
        if (languageKeys.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.translate_rounded,
                    size: 16, color: AppColors.textTertiary),
              ),
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
            ],
          ),
        ],
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
