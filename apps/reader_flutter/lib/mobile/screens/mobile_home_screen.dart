import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/continue_reading_provider.dart';
import '../../providers/engagement_providers.dart';
import '../../providers/session_notifier.dart';
import '../../utils/catalog_categories.dart';
import '../../utils/catalog_language_label.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/liquid_glass_nav_bar.dart';
import '../../widgets/skeleton_loader.dart';
import '../widgets/catalog/catalog_filter_tabs.dart';
import '../widgets/catalog/continue_reading_card.dart';
import '../widgets/catalog/featured_carousel.dart';
import '../widgets/catalog/genre_chip_row.dart';
import '../widgets/catalog/mobile_book_card.dart';
import '../widgets/catalog/mobile_home_header.dart';

/// Reference-styled mobile home: top bar, search, featured "Popular" card,
/// genre chips and a poster grid. Typing a query switches to search-results
/// mode (filter tabs + grid), mirroring the two reference screens.
class MobileHomeScreen extends ConsumerStatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  ConsumerState<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

enum _SortMode { titleAz, newest, oldest, popular, topRated }

class _MobileHomeScreenState extends ConsumerState<MobileHomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _genre;
  String? _language;
  _SortMode _sort = _SortMode.titleAz;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced so the (potentially large) grid only re-filters once typing
  /// settles, keeping keystrokes smooth.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted && value != _query) setState(() => _query = value);
    });
  }

  String _sortLabel(AppLocalizations l10n, _SortMode m) => switch (m) {
    _SortMode.titleAz => l10n.sortTitleAz,
    _SortMode.newest => l10n.sortNewest,
    _SortMode.oldest => l10n.sortOldest,
    _SortMode.popular => l10n.sortPopular,
    _SortMode.topRated => l10n.sortTopRated,
  };

  void _applySort(List<BookSummary> list) {
    int byDate(BookSummary a, BookSummary b) =>
        (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
    double pop(BookSummary b) =>
        b.readersCount + b.ratingAverage * b.ratingCount * 2;
    switch (_sort) {
      case _SortMode.titleAz:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SortMode.newest:
        list.sort((a, b) => byDate(b, a));
      case _SortMode.oldest:
        list.sort(byDate);
      case _SortMode.popular:
        list.sort((a, b) => pop(b).compareTo(pop(a)));
      case _SortMode.topRated:
        list.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
    }
  }

  List<({String key, String label})> _languageOptions(
    List<BookSummary> books,
    AppLocalizations l10n,
  ) {
    final seen = <String, String>{};
    for (final b in books) {
      final k = catalogLanguageFilterKey(b.primaryLanguage, l10n);
      seen.putIfAbsent(
        k,
        () => catalogLanguageFilterLabel(b.primaryLanguage, l10n),
      );
    }
    final list = seen.entries.map((e) => (key: e.key, label: e.value)).toList();
    list.sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  Future<void> _openFilterSheet(AppLocalizations l10n) async {
    final books = ref.read(catalogProvider).valueOrNull?.items ?? const [];
    final languages = _languageOptions(books, l10n);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheet) {
            void update(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (languages.length > 1) ...[
                    _sheetHeader(l10n.languagesMetric),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: l10n.filterAll,
                          active: _language == null,
                          onTap: () => update(() => _language = null),
                        ),
                        for (final lang in languages)
                          _SheetChip(
                            label: lang.label,
                            active: _language == lang.key,
                            onTap: () => update(() => _language = lang.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  _sheetHeader(l10n.sortLabel),
                  const SizedBox(height: 4),
                  for (final m in _SortMode.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_sortLabel(l10n, m)),
                      trailing: _sort == m
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () => update(() => _sort = m),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSearchSheet(AppLocalizations l10n) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MobileSearchBar(
              hint: l10n.homeSearchHint,
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onFilterTap: () {
                Navigator.of(sheetContext).pop();
                _openFilterSheet(l10n);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  child: Text(l10n.clear),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.textTertiary,
      letterSpacing: 0.3,
    ),
  );

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    ref.invalidate(lastOpenedBookProvider);
    await ref.read(catalogProvider.future);
  }

  List<BookSummary> _filtered(List<BookSummary> books) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final result = books.where((b) {
      if (bibleHiddenForGenre(b, _genre)) return false;
      if (_genre != null && (b.genre ?? '').trim() != _genre) return false;
      if (_language != null &&
          catalogLanguageFilterKey(b.primaryLanguage, l10n) != _language) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        b.title,
        b.authorCompiler ?? '',
        b.subtitle ?? '',
        b.summary ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
    _applySort(result);
    return result;
  }

  /// Genre filter chips: the dynamic genres lookup, limited to genres actually
  /// present in the catalog, plus any legacy slugs not in the lookup.
  List<GenreOption> _genreOptions(List<BookSummary> books) {
    final lookup =
        ref.watch(genresProvider).valueOrNull ?? const <GenreOption>[];
    final present = <String>{for (final b in books) (b.genre ?? '').trim()}
      ..removeWhere((s) => s.isEmpty);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(catalogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => _Frame(
            header: _header(l10n),
            onRefresh: _refresh,
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pageHorizontal,
                  16,
                  AppLayout.pageHorizontal,
                  0,
                ),
                child: SkeletonCardGroup(count: 4),
              ),
            ],
          ),
          error: (e, _) => _Frame(
            header: _header(l10n),
            onRefresh: _refresh,
            children: [
              AppStateView(
                title: l10n.unableToLoadHome,
                message: '$e',
                icon: Icons.cloud_off_outlined,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(catalogProvider),
              ),
            ],
          ),
          data: (page) => _buildData(l10n, page.items),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;
    final name = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!.trim()
        : l10n.appTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal,
        12,
        AppLayout.pageHorizontal,
        4,
      ),
      child: Column(
        children: [
          MobileHomeTopBar(
            name: name,
            email: user?.email,
            verified: user != null,
            searchActive: _query.trim().isNotEmpty,
            onSearch: () => _openSearchSheet(l10n),
            notificationCount:
                ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
            onFavourites: () => context.push('/favourites'),
            onNotifications: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildData(AppLocalizations l10n, List<BookSummary> books) {
    if (books.isEmpty) {
      return _Frame(
        header: _header(l10n),
        onRefresh: _refresh,
        children: [
          AppStateView(
            title: l10n.homeNoBooksTitle,
            message: l10n.homeNoBooksMessage,
            icon: Icons.menu_book_outlined,
          ),
        ],
      );
    }

    final genreOptions = _genreOptions(books);
    final filtered = _filtered(books);
    final searching = _query.trim().isNotEmpty;

    // Continue reading.
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    BookSummary? resumeBook;
    if (lastOpened != null && lastOpened.bookId.isNotEmpty) {
      final match = books.where((b) => b.id == lastOpened.bookId);
      if (match.isNotEmpty) resumeBook = match.first;
    }
    final resumeIndex = resumeBook == null ? 0 : books.indexOf(resumeBook);

    return _Frame(
      header: _header(l10n),
      onRefresh: _refresh,
      children: [
        if (!searching) ...[
          const SizedBox(height: 14),
          FeaturedCarousel(
            books:
                ref.watch(featuredBooksProvider).valueOrNull ?? [books.first],
          ),
          const SizedBox(height: 18),
          GenreChipRow(
            options: genreOptions,
            selected: _genre,
            onSelected: (c) => setState(() => _genre = c),
          ),
          if (resumeBook != null) ...[
            const SizedBox(height: 20),
            _SectionHeader(
              title: l10n.continueReading,
              actionLabel: l10n.viewAll,
              onAction: () => context.push('/downloads'),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.pageHorizontal,
              ),
              child: ContinueReadingCard(
                book: resumeBook,
                index: resumeIndex < 0 ? 0 : resumeIndex,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionHeader(title: l10n.homeSectionExplore),
          const SizedBox(height: 4),
        ] else ...[
          const SizedBox(height: 14),
          CatalogFilterTabs(
            options: genreOptions,
            selected: _genre,
            onSelected: (c) => setState(() => _genre = c),
          ),
          const SizedBox(height: 14),
        ],
        _BookGrid(books: filtered, allBooks: books),
      ],
    );
  }
}

/// Shared scroll frame: pinned header + refreshable scroll body.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.header,
    required this.onRefresh,
    required this.children,
  });

  final Widget header;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(
                bottom: LiquidGlassNavBar.bottomInset,
              ),
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.pageHorizontal),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selectable pill used inside the filter sheet.
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.allBooks});

  final List<BookSummary> books;
  final List<BookSummary> allBooks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: AppStateView(
          title: l10n.noMatchingBooksTitle,
          message: l10n.noMatchingBooksMessage,
          icon: Icons.search_off_rounded,
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal,
        10,
        AppLayout.pageHorizontal,
        8,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.62,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        // Stable index into the full list keeps gradient assignment consistent.
        final globalIndex = allBooks.indexOf(books[i]);
        return MobileBookCard(
          book: books[i],
          index: globalIndex < 0 ? i : globalIndex,
        );
      },
    );
  }
}
