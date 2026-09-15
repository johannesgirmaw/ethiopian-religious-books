import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../providers/nav_visibility_providers.dart';
import '../../../providers/session_notifier.dart';
import '../../../l10n/app_localizations.dart';
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

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionNotifierProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: WebTokens.sidebarDecoration(),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: WebTokens.sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Same height as the main header so the mark+wordmark sit on one
              // line with EN / notifications / user. Same inset as nav rows.
              SizedBox(
                height: WebTokens.navHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: InkWell(
                    onTap: () => context.go('/home'),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppBrandWordmark(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: WebTokens.borderColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                child: _SignOutLink(
                  label: l10n.signOut,
                  onTap: () => _signOut(context, ref),
                ),
              ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? WebTokens.sidebarSelectedBg : Colors.transparent,
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
                      color: color,
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

class _SignOutLink extends StatelessWidget {
  const _SignOutLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
