import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../design/web_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/continue_reading_provider.dart';
import '../../providers/session_notifier.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shared_widgets.dart';
import '../../widgets/skeleton_loader.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/catalog/catalog_browse_panel.dart';
import '../widgets/catalog/web_continue_reading_strip.dart';
import '../widgets/common/web_page_header.dart';

class HomeScreenBody extends ConsumerStatefulWidget {
  const HomeScreenBody({super.key});

  @override
  ConsumerState<HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends ConsumerState<HomeScreenBody> {
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
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));

    Widget searchField() {
      return TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          filled: true,
          fillColor: WebTokens.surfaceBg,
          hintText: l10n.librarySearchHint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: WebTokens.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: WebTokens.borderColor),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return async.when(
      data: (page) {
        if (page.items.isEmpty) {
          return ListView(
            padding: padding,
            children: [
              WebPageHeader(
                title: l10n.navHome,
                subtitle: '${greetingForL10n(l10n)}, ${_welcomeName(l10n, session)}',
              ),
              const SizedBox(height: 24),
              AppStateView(
                title: l10n.homeNoBooksTitle,
                message: l10n.homeNoBooksMessage,
                icon: Icons.menu_book_outlined,
              ),
            ],
          );
        }

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebPageHeader(
                title: l10n.navHome,
                subtitle:
                    '${greetingForL10n(l10n)}, ${_welcomeName(l10n, session)} · ${l10n.booksAvailable(page.items.length)}',
                bottom: searchField(),
              ),
              if (resumeBookId != null) ...[
                const SizedBox(height: 20),
                WebContinueReadingStrip(bookId: resumeBookId),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: WebCatalogBrowsePanel(
                  books: page.items,
                  onRefresh: _refresh,
                  searchQuery: _searchQuery,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => ListView(
        padding: padding,
        children: [
          WebPageHeader(
            title: l10n.navHome,
            subtitle: greetingForL10n(l10n),
          ),
          const SizedBox(height: 24),
          const SkeletonCardGroup(count: 4),
        ],
      ),
      error: (e, _) => ListView(
        padding: padding,
        children: [
          WebPageHeader(title: l10n.navHome),
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
    );
  }
}
