import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../models/user_profile.dart';
import '../../../providers/nav_visibility_providers.dart';
import '../../../providers/session_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/sidebar_identity.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import '../../design/desktop_tokens.dart';

class DesktopSidebarItem {
  const DesktopSidebarItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.shortcut,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? shortcut;
}

/// Persistent left navigation rail for native desktop shell.
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({
    super.key,
    required this.currentLocation,
    required this.items,
  });

  final String currentLocation;
  final List<DesktopSidebarItem> items;

  bool _isSelected(String route) {
    if (route == '/home') return currentLocation.startsWith('/home');
    if (route == '/profile') {
      return currentLocation.startsWith('/profile');
    }
    if (route == '/admin') {
      return currentLocation.startsWith('/admin');
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
      decoration: DesktopTokens.sidebarDecoration(),
      child: SizedBox(
        width: DesktopTokens.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand lockup: stacked Amharic wordmark logo.
            const SizedBox(
              height: DesktopTokens.titleBarHeight + 12,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppBrandWordmark(
                    fontSize: 16,
                    stacked: true,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SidebarLink(
                      item: items[i],
                      selected: _isSelected(items[i].route),
                      onTap: () => context.go(items[i].route),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DesktopUserCard(user: user),
          ],
        ),
      ),
    );
  }
}

/// Footer identity card: avatar + display name + email. Taps through to profile.
class _DesktopUserCard extends StatelessWidget {
  const _DesktopUserCard({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final name = sidebarUserName(user);
    final subtitle = sidebarUserSubtitle(user);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DesktopTokens.canvasBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DesktopTokens.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    sidebarInitial(name),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
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

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DesktopSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? DesktopTokens.sidebarSelectedBg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: selected
                      ? AppColors.primaryDeep
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primaryDeep
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (item.shortcut != null)
                  Text(
                    item.shortcut!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
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

/// Sidebar items for the current session — use on every desktop shell/overlay page.
List<DesktopSidebarItem> desktopSidebarItemsFor(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
  return defaultDesktopSidebarItems(
    l10n,
    isAdmin: user?.isPlatformAdmin ?? false,
    canManageBooks: user?.canManageBooks ?? false,
    hasBibleContent: ref.watch(hasBibleContentProvider).valueOrNull ?? false,
    hasPurchases: ref.watch(hasPurchasesProvider).valueOrNull ?? false,
  );
}

List<DesktopSidebarItem> defaultDesktopSidebarItems(
  AppLocalizations l10n, {
  bool isAdmin = false,
  bool canManageBooks = false,
  bool hasBibleContent = false,
  bool hasPurchases = false,
}) {
  return [
    DesktopSidebarItem(
      route: '/home',
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: l10n.navHome,
      shortcut: '⌘1',
    ),
    // Bible / Purchases only appear once they have something to show.
    if (hasBibleContent)
      DesktopSidebarItem(
        route: '/bible',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        label: l10n.bibleTitle,
      ),
    if (hasPurchases)
      DesktopSidebarItem(
        route: '/purchases',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.paymentMyPurchases,
      ),
    DesktopSidebarItem(
      route: '/settings',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      label: l10n.navSettings,
      shortcut: '⌘2',
    ),
    DesktopSidebarItem(
      route: '/profile',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: l10n.navProfile,
      shortcut: '⌘3',
    ),
    if (isAdmin || canManageBooks)
      DesktopSidebarItem(
        route: '/admin/books',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        label: isAdmin ? l10n.adminBooksMenuTitle : l10n.authorMyBooks,
      ),
    if (isAdmin)
      DesktopSidebarItem(
        route: '/admin/payments',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.adminPaymentsTitle,
      ),
    if (isAdmin)
      DesktopSidebarItem(
        route: '/admin/author-applications',
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.adminAuthorAppsTitle,
      ),
  ];
}

/// Keyboard shortcuts for sidebar navigation.
class DesktopNavShortcuts extends StatelessWidget {
  const DesktopNavShortcuts({
    super.key,
    required this.child,
    required this.items,
  });

  final Widget child;
  final List<DesktopSidebarItem> items;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1):
          const _DesktopNavIntent('/home'),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2):
          const _DesktopNavIntent('/settings'),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3):
          const _DesktopNavIntent('/profile'),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
          const _DesktopNavIntent('/home'),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2):
          const _DesktopNavIntent('/settings'),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3):
          const _DesktopNavIntent('/profile'),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _DesktopNavIntent: CallbackAction<_DesktopNavIntent>(
            onInvoke: (intent) {
              context.go(intent.route);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _DesktopNavIntent extends Intent {
  const _DesktopNavIntent(this.route);
  final String route;
}
