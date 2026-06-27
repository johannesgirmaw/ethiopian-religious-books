import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../providers/session_notifier.dart';
import '../../../design/reference_assets.dart';
import '../../../l10n/app_localizations.dart';
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
class WebSidebar extends StatelessWidget {
  const WebSidebar({
    super.key,
    required this.currentLocation,
    required this.items,
    required this.appTitle,
  });

  final String currentLocation;
  final List<WebSidebarItem> items;
  final String appTitle;

  bool _isSelected(String route) {
    if (route == '/home') {
      return currentLocation.startsWith('/home');
    }
    if (route == '/profile') {
      return currentLocation.startsWith('/profile');
    }
    return currentLocation.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: WebTokens.sidebarDecoration(),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: WebTokens.sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                child: InkWell(
                  onTap: () => context.go('/home'),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppGradients.gold,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          ReferenceAssets.appLogo,
                          fit: BoxFit.contain,
                          color: AppColors.primaryDeep,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'NAVIGATION',
                  style: WebTokens.sectionLabelStyle,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WebTokens.canvasBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: WebTokens.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      AppLocalizations.of(context)!.splashTagline,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
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
              color: selected ? WebTokens.sidebarSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: AppColors.referencePrimary.withValues(alpha: 0.18),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected
                      ? AppColors.referencePrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.referencePrimary
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

/// Sidebar items for the current session — use on every web shell/overlay page.
List<WebSidebarItem> webSidebarItemsFor(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
  return defaultWebSidebarItems(
    l10n,
    isAdmin: user?.isPlatformAdmin ?? false,
    canManageBooks: user?.canManageBooks ?? false,
  );
}

List<WebSidebarItem> defaultWebSidebarItems(
  AppLocalizations l10n, {
  bool isAdmin = false,
  bool canManageBooks = false,
}) {
  return [
    WebSidebarItem(
      route: '/home',
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: l10n.navHome,
    ),
    WebSidebarItem(
      route: '/downloads',
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
      label: l10n.downloadsPageTitle,
    ),
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
        icon: isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.menu_book_outlined,
        selectedIcon: isAdmin
            ? Icons.admin_panel_settings_rounded
            : Icons.menu_book_rounded,
        label: isAdmin ? l10n.adminHomeTitle : l10n.authorMyBooks,
      ),
    if (isAdmin)
      WebSidebarItem(
        route: '/admin/payments',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.adminPaymentsTitle,
      ),
  ];
}
