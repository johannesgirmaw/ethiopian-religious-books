import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../models/user_profile.dart';
import '../../../providers/nav_visibility_providers.dart';
import '../../../providers/session_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/sidebar_identity.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import '../../design/web_tokens.dart';

class WebSidebarItem {
  const WebSidebarItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Persistent left navigation for the web app shell.
class WebSidebar extends ConsumerWidget {
  const WebSidebar({
    super.key,
    required this.currentLocation,
    required this.items,
  });

  final String currentLocation;
  final List<WebSidebarItem> items;

  bool _isSelected(String route) {
    if (route == '/home') {
      return currentLocation.startsWith('/home');
    }
    if (route == '/profile') {
      return currentLocation.startsWith('/profile');
    }
    if (route == '/settings') {
      // Downloads now lives under Settings — keep Settings highlighted there.
      return currentLocation.startsWith('/settings') ||
          currentLocation.startsWith('/downloads');
    }
    return currentLocation.startsWith(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;

    return DecoratedBox(
      decoration: WebTokens.sidebarDecoration(),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: WebTokens.sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand lockup: stacked Amharic wordmark logo.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: InkWell(
                  onTap: () => context.go('/home'),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: AppBrandWordmark(
                      fontSize: 22,
                      stacked: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final item in items)
                      _SidebarLink(
                        item: item,
                        selected: _isSelected(item.route),
                        onTap: () => context.go(item.route),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: WebTokens.borderColor),
              _UserCard(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WebSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDeep : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? WebTokens.sidebarSelectedBg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primaryDeep
                          : AppColors.textPrimary,
                    ),
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

/// Footer identity card: avatar + display name + role. Taps through to profile.
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final name = sidebarUserName(user);
    final subtitle = sidebarUserSubtitle(user);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: WebTokens.canvasBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WebTokens.borderColor),
            ),
            child: Row(
              children: [
                _SidebarAvatar(initial: sidebarInitial(name)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
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

class _SidebarAvatar extends StatelessWidget {
  const _SidebarAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Sidebar items for the current session — use on every web shell/overlay page.
List<WebSidebarItem> webSidebarItemsFor(WidgetRef ref, AppLocalizations l10n) {
  final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
  return defaultWebSidebarItems(
    l10n,
    isAdmin: user?.isPlatformAdmin ?? false,
    canManageBooks: user?.canManageBooks ?? false,
    hasBibleContent: ref.watch(hasBibleContentProvider).valueOrNull ?? false,
    hasPurchases: ref.watch(hasPurchasesProvider).valueOrNull ?? false,
  );
}

List<WebSidebarItem> defaultWebSidebarItems(
  AppLocalizations l10n, {
  bool isAdmin = false,
  bool canManageBooks = false,
  bool hasBibleContent = false,
  bool hasPurchases = false,
}) {
  return [
    WebSidebarItem(
      route: '/home',
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: l10n.navHome,
    ),
    // Bible / Purchases only appear once they have something to show.
    if (hasBibleContent)
      WebSidebarItem(
        route: '/bible',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        label: l10n.bibleTitle,
      ),
    if (hasPurchases)
      WebSidebarItem(
        route: '/purchases',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.paymentMyPurchases,
      ),
    WebSidebarItem(
      route: '/settings',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      label: l10n.navSettings,
    ),
    WebSidebarItem(
      route: '/profile',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: l10n.navProfile,
    ),
    if (isAdmin || canManageBooks)
      WebSidebarItem(
        route: '/admin/books',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        label: isAdmin ? l10n.adminBooksMenuTitle : l10n.authorMyBooks,
      ),
    if (isAdmin)
      WebSidebarItem(
        route: '/admin/payments',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.navOrders,
      ),
    if (isAdmin)
      WebSidebarItem(
        route: '/admin/author-applications',
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.adminAuthorAppsTitle,
      ),
  ];
}
