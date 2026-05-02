import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../utils/format_catalog_cache_age.dart';
import '../widgets/app_state_view.dart';
import '../widgets/skeleton_loader.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedLanguage;
  String? _selectedChapter;
  int? _selectedPage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterMenu(List<BookSummary> allBooks) async {
    final l10n = AppLocalizations.of(context)!;
    final languages = allBooks
        .map((e) => (e.primaryLanguage ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final chapterController = TextEditingController(text: _selectedChapter ?? '');
    final pageController = TextEditingController(
      text: _selectedPage == null ? '' : _selectedPage.toString(),
    );
    final choice = await showModalBottomSheet<({String? language, String? chapter, int? page})>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  l10n.filterByLanguage,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: Icon(
                  _selectedLanguage == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(l10n.allLanguages),
                onTap: () => Navigator.of(context).pop((
                  language: null,
                  chapter: chapterController.text.trim().isEmpty
                      ? null
                      : chapterController.text.trim(),
                  page: int.tryParse(pageController.text.trim()),
                )),
              ),
              ...languages.map(
                (lang) => ListTile(
                  leading: Icon(
                    _selectedLanguage == lang
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(lang),
                  onTap: () => Navigator.of(context).pop((
                    language: lang,
                    chapter: chapterController.text.trim().isEmpty
                        ? null
                        : chapterController.text.trim(),
                    page: int.tryParse(pageController.text.trim()),
                  )),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: chapterController,
                  decoration: InputDecoration(
                    labelText: l10n.chapterKeyLabel,
                    hintText: l10n.chapterKeyHint,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.pageNumberLabel,
                    hintText: l10n.pageNumberHint,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop((
                      language: _selectedLanguage,
                      chapter: chapterController.text.trim().isEmpty
                          ? null
                          : chapterController.text.trim(),
                      page: int.tryParse(pageController.text.trim()),
                    ));
                  },
                  child: Text(l10n.applyFilters),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (choice != null) {
      setState(() {
        _selectedLanguage = choice.language;
        _selectedChapter = choice.chapter;
        _selectedPage = (choice.page != null && choice.page! > 0) ? choice.page : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final useRemoteSearch =
        _query.trim().isNotEmpty || (_selectedChapter ?? '').isNotEmpty || _selectedPage != null;
    final async = useRemoteSearch
        ? ref.watch(
            catalogSearchProvider(
              CatalogSearchFilters(
                query: _query,
                chapter: _selectedChapter,
                page: _selectedPage,
              ),
            ),
          )
        : ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: [
          async.maybeWhen(
            data: (page) => IconButton(
              tooltip: l10n.filterTooltip,
              onPressed: () => _openFilterMenu(page.items),
              icon: const Icon(Icons.tune_rounded),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        data: (page) {
          final filteredBooks =
              useRemoteSearch ? _applyLocalLanguageFilter(page.items) : _applyFilters(page.items);
          if (page.items.isEmpty) {
            return AppStateView(
              title: l10n.libraryEmptyTitle,
              message: l10n.libraryEmptyMessage,
              icon: Icons.library_books_outlined,
            );
          }
          final categories = _groupByLanguage(filteredBooks, l10n);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(catalogProvider);
              await ref.read(catalogProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (cachedAt != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.library_books_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.showingLibrarySynced(
                              formatCatalogCacheAge(l10n, cachedAt),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.librarySearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearSearchTooltip,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.booksAvailable(filteredBooks.length),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (_selectedLanguage != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedLanguage = null;
                            _selectedChapter = null;
                            _selectedPage = null;
                          }),
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                          label: Text(l10n.clearFilter),
                        ),
                    ],
                  ),
                ),
                if (_selectedLanguage != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(l10n.languageChip(_selectedLanguage!)),
                        onDeleted: () =>
                            setState(() => _selectedLanguage = null),
                      ),
                      if ((_selectedChapter ?? '').isNotEmpty)
                        Chip(
                          label: Text(l10n.chapterChip(_selectedChapter!)),
                          onDeleted: () => setState(() => _selectedChapter = null),
                        ),
                      if (_selectedPage != null)
                        Chip(
                          label: Text(l10n.pageChip(_selectedPage!)),
                          onDeleted: () => setState(() => _selectedPage = null),
                        ),
                    ],
                  ),
                if (filteredBooks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: AppStateView(
                      title: l10n.noMatchingBooksTitle,
                      message: l10n.noMatchingBooksMessage,
                      icon: Icons.search_off_rounded,
                    ),
                  )
                else
                  ...categories.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: entry.value.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final b = entry.value[i];
                                return _BookCategoryCard(book: b);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const SkeletonCardGroup(count: 4),
        error: (e, _) => AppStateView(
          title: l10n.unableToLoadLibrary,
          message: '$e',
          icon: Icons.cloud_off_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(catalogProvider),
        ),
      ),
    );
  }

  List<BookSummary> _applyFilters(List<BookSummary> books) {
    final q = _query.toLowerCase();
    return books.where((book) {
      final langMatch = _selectedLanguage == null ||
          (book.primaryLanguage ?? '').trim() == _selectedLanguage;
      if (!langMatch) return false;
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

  List<BookSummary> _applyLocalLanguageFilter(List<BookSummary> books) {
    return books.where((book) {
      return _selectedLanguage == null ||
          (book.primaryLanguage ?? '').trim() == _selectedLanguage;
    }).toList();
  }

  Map<String, List<BookSummary>> _groupByLanguage(
    List<BookSummary> books,
    AppLocalizations l10n,
  ) {
    final map = <String, List<BookSummary>>{};
    for (final b in books) {
      final key = (b.primaryLanguage ?? '').trim().isEmpty
          ? l10n.generalCategory
          : b.primaryLanguage!.trim();
      map.putIfAbsent(key, () => []);
      map[key]!.add(b);
    }
    return map;
  }
}

class _BookCategoryCard extends StatelessWidget {
  const _BookCategoryCard({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rev = book.publishedRevision;
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/book/${book.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (book.authorCompiler != null &&
                        book.authorCompiler!.isNotEmpty)
                      book.authorCompiler!,
                    if (rev != null && rev.revisionNumber > 0)
                      l10n.revisionLabel(rev.revisionNumber),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  l10n.open,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
