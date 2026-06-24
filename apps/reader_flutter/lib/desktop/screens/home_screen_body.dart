import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/continue_reading_provider.dart';
import '../../providers/engagement_providers.dart';
import '../../providers/session_notifier.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shared_widgets.dart';
import '../../widgets/skeleton_loader.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/catalog/catalog_browse_panel.dart';
import '../widgets/catalog/desktop_continue_reading_strip.dart';
import '../widgets/catalog/desktop_featured_carousel.dart';
import '../widgets/common/desktop_page_header.dart';

class DesktopHomeScreenBody extends ConsumerStatefulWidget {
  const DesktopHomeScreenBody({super.key});

  @override
  ConsumerState<DesktopHomeScreenBody> createState() =>
      _DesktopHomeScreenBodyState();
}

class _DesktopHomeScreenBodyState extends ConsumerState<DesktopHomeScreenBody> {
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    ref.invalidate(lastOpenedBookProvider);
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineDownloadsListProvider);
    await ref.read(catalogProvider.future);
  }

  String _welcomeName(AppLocalizations l10n, Session? session) {
    final name = session?.user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return l10n.readerAccount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final resumeBookId =
        lastOpened != null && lastOpened.bookId.isNotEmpty
            ? lastOpened.bookId
            : null;
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));

    return async.when(
      data: (page) {
        if (page.items.isEmpty) {
          return ListView(
            padding: padding,
            children: [
              DesktopPageHeader(
                title: l10n.navHome,
                subtitle:
                    '${greetingForL10n(l10n)}, ${_welcomeName(l10n, session)}',
              ),
              const SizedBox(height: 20),
              AppStateView(
                title: l10n.homeNoBooksTitle,
                message: l10n.homeNoBooksMessage,
                icon: Icons.menu_book_outlined,
              ),
            ],
          );
        }

        return DesktopCatalogBrowsePanel(
          books: page.items,
          onRefresh: _refresh,
          searchQuery: _searchQuery,
          padding: padding,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopPageHeader(
                title: l10n.navHome,
                subtitle:
                    '${greetingForL10n(l10n)}, ${_welcomeName(l10n, session)} · ${l10n.booksAvailable(page.items.length)}',
                actions: [
                  DesktopSearchField(
                    controller: _searchCtrl,
                    hintText: l10n.librarySearchHint,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ],
              ),
              if (_searchQuery.trim().isEmpty) ...[
                const SizedBox(height: 16),
                DesktopFeaturedCarousel(
                  books: ref.watch(featuredBooksProvider).valueOrNull ??
                      [page.items.first],
                ),
              ],
              if (resumeBookId != null) ...[
                const SizedBox(height: 12),
                DesktopContinueReadingStrip(bookId: resumeBookId),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      loading: () => ListView(
        padding: padding,
        children: [
          DesktopPageHeader(
            title: l10n.navHome,
            subtitle: greetingForL10n(l10n),
          ),
          const SizedBox(height: 20),
          const SkeletonCardGroup(count: 6),
        ],
      ),
      error: (e, _) => ListView(
        padding: padding,
        children: [
          DesktopPageHeader(title: l10n.navHome),
          const SizedBox(height: 20),
          AppStateView(
            title: l10n.unableToLoadHome,
            message: '$e',
            icon: Icons.cloud_off_outlined,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(catalogProvider),
          ),
        ],
      ),
    );
  }
}
