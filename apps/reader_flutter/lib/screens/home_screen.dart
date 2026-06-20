import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../desktop/screens/home_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/session_notifier.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/home_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';
import '../widgets/app_state_view.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/reference/catalog_browse_panel.dart';
import '../widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greetingTitle(AppLocalizations l10n, Session? session) {
    final name = session?.user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return l10n.appTitle;
  }

  Widget _homeBanner(AppLocalizations l10n, Session? session) {
    return AppGreetingCard(
      greetingLine: greetingForL10n(l10n),
      title: _greetingTitle(l10n, session),
      subtitle: l10n.splashTagline,
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogProvider);
    ref.invalidate(lastOpenedBookProvider);
    ref.invalidate(offlineBookCountProvider);
    ref.invalidate(offlineDownloadsListProvider);
    await ref.read(catalogProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(catalogProvider);
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final resumeBookId =
        lastOpened != null && lastOpened.bookId.isNotEmpty
            ? lastOpened.bookId
            : null;
    final banner = _homeBanner(l10n, session);

    if (useWebShell(context)) {
      return const WebPageScaffold(body: HomeScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopHomeScreenBody());
    }

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      floatingActionButton: resumeBookId != null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/reader/$resumeBookId'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.resumeReading),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: async.when(
          data: (page) {
            if (page.items.isEmpty) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _refresh(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    banner,
                    AppStateView(
                      title: l10n.homeNoBooksTitle,
                      message: l10n.homeNoBooksMessage,
                      icon: Icons.menu_book_outlined,
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                banner,
                Expanded(
                  child: CatalogBrowsePanel(
                    books: page.items,
                    onRefresh: () => _refresh(ref),
                    bottomPadding: resumeBookId != null ? 104 : AppLayout.pageBottom,
                  ),
                ),
              ],
            );
          },
          loading: () => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                banner,
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageHorizontal,
                    AppLayout.blockGap,
                    AppLayout.pageHorizontal,
                    AppLayout.blockGap,
                  ),
                  child: SkeletonCardGroup(count: 4),
                ),
              ],
            ),
          ),
          error: (e, _) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                banner,
                AppStateView(
                  title: l10n.unableToLoadHome,
                  message: '$e',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(catalogProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
