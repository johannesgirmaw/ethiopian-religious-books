import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../utils/catalog_categories.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/continue_reading_provider.dart';
import '../../providers/engagement_providers.dart';
import '../../providers/session_notifier.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/home/home_filters.dart';
import '../../widgets/home/home_sections.dart';
import '../../widgets/skeleton_loader.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/catalog/catalog_grid_delegate.dart';
import '../widgets/catalog/desktop_book_card.dart';
import '../widgets/catalog/desktop_continue_reading_strip.dart';
import '../widgets/catalog/desktop_featured_carousel.dart';

class DesktopHomeScreenBody extends ConsumerStatefulWidget {
  const DesktopHomeScreenBody({super.key});

  @override
  ConsumerState<DesktopHomeScreenBody> createState() =>
      _DesktopHomeScreenBodyState();
}

class _DesktopHomeScreenBodyState extends ConsumerState<DesktopHomeScreenBody> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _genre;
  String? _language;
  HomeSort _sort = HomeSort.titleAz;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted && v != _query) setState(() => _query = v);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    ref.invalidate(lastOpenedBookProvider);
    await ref.read(catalogProvider.future);
  }

  List<BookSummary> _filtered(List<BookSummary> books, AppLocalizations l10n) {
    final q = _query.trim().toLowerCase();
    final result = books.where((b) {
      if (bibleHiddenForGenre(b, _genre)) return false;
      if (_genre != null && (b.genre ?? '').trim() != _genre) return false;
      if (!bookMatchesLanguage(b, _language, l10n)) return false;
      if (q.isEmpty) return true;
      return [b.title, b.authorCompiler ?? '', b.subtitle ?? '', b.summary ?? '']
          .join(' ')
          .toLowerCase()
          .contains(q);
    }).toList();
    applyHomeSort(result, _sort);
    return result;
  }

  Widget _topBar(AppLocalizations l10n) {
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    final name = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!.trim()
        : l10n.readerAccount;
    return HomeTopBar(
      name: name,
      email: user?.email,
      verified: user != null,
      notificationCount:
          ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
      onFavourites: () => context.push('/favourites'),
      onNotifications: () => context.push('/notifications'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final tier = DesktopLayoutScope.tierOf(context);
    final insets = DesktopTokens.pagePadding(tier)
        .resolve(Directionality.of(context));

    return async.when(
      loading: () => ListView(
        padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
        children: [_topBar(l10n), const SizedBox(height: 24), const SkeletonCardGroup(count: 6)],
      ),
      error: (e, _) => ListView(
        padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
        children: [
          _topBar(l10n),
          const SizedBox(height: 24),
          AppStateView(
            title: l10n.unableToLoadHome,
            message: '$e',
            icon: Icons.cloud_off_outlined,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(catalogProvider),
          ),
        ],
      ),
      data: (page) => _buildData(context, l10n, page.items, insets),
    );
  }

  Widget _buildData(
    BuildContext context,
    AppLocalizations l10n,
    List<BookSummary> books,
    EdgeInsets insets,
  ) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        _topBar(l10n),
        const SizedBox(height: 20),
        HomeSearchBar(
          hint: l10n.homeSearchHint,
          controller: _searchCtrl,
          onChanged: _onSearch,
          onFilterTap: () => showHomeFilterSheet(
            context: context,
            l10n: l10n,
            languages: languageOptionsFor(books, l10n),
            selectedLanguage: _language,
            selectedSort: _sort,
            onLanguage: (v) => setState(() => _language = v),
            onSort: (v) => setState(() => _sort = v),
          ),
        ),
      ],
    );

    if (books.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
        children: [
          header,
          const SizedBox(height: 24),
          AppStateView(
            title: l10n.homeNoBooksTitle,
            message: l10n.homeNoBooksMessage,
            icon: Icons.menu_book_outlined,
          ),
        ],
      );
    }

    final searching = _query.trim().isNotEmpty;
    final genreOptions =
        genreOptionsFor(books, ref.watch(genresProvider).valueOrNull ?? const []);
    final filtered = _filtered(books, l10n);

    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final resumeId = (lastOpened != null && lastOpened.bookId.isNotEmpty)
        ? lastOpened.bookId
        : null;
    final headerChildren = <Widget>[
      header,
      const SizedBox(height: 22),
      if (!searching) ...[
        DesktopFeaturedCarousel(
          books: ref.watch(featuredBooksProvider).valueOrNull ?? [books.first],
        ),
        const SizedBox(height: 22),
        HomeGenreChips(
          options: genreOptions,
          selected: _genre,
          onSelected: (g) => setState(() => _genre = g),
        ),
        if (resumeId != null) ...[
          const SizedBox(height: 24),
          HomeSectionHeader(title: l10n.continueReading),
          const SizedBox(height: 12),
          DesktopContinueReadingStrip(bookId: resumeId),
        ],
        const SizedBox(height: 24),
        HomeSectionHeader(title: l10n.homeSectionExplore),
        const SizedBox(height: 12),
      ] else ...[
        HomeFilterTabs(
          options: genreOptions,
          selected: _genre,
          onSelected: (g) => setState(() => _genre = g),
        ),
        const SizedBox(height: 16),
      ],
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding:
                EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: headerChildren,
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppStateView(
                title: l10n.noMatchingBooksTitle,
                message: l10n.noMatchingBooksMessage,
                icon: Icons.search_off_rounded,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  insets.left, 0, insets.right, insets.bottom),
              sliver: SliverGrid(
                gridDelegate: desktopCatalogGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      DesktopBookCard(book: filtered[i], index: i),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

