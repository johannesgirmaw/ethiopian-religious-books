import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../providers/nav_visibility_providers.dart';
import '../../../providers/session_notifier.dart';
import '../../../l10n/app_localizations.dart';
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

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionNotifierProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: DesktopTokens.sidebarDecoration(),
      child: SizedBox(
        width: DesktopTokens.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand lockup aligned with the persistent shell header.
            const SizedBox(
              height: DesktopTokens.toolbarHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(child: AppBrandWordmark(fontSize: 16)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: _SignOutLink(
                label: l10n.signOut,
                onTap: () => _signOut(context, ref),
              ),
            ),
          ],
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
    final color = selected ? AppColors.primaryDeep : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
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
