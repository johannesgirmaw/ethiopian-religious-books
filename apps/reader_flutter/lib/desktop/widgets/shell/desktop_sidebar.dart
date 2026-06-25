import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../design/reference_assets.dart';
import '../../../l10n/app_localizations.dart';
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
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentLocation,
    required this.items,
    required this.appTitle,
  });

  final String currentLocation;
  final List<DesktopSidebarItem> items;
  final String appTitle;

  bool _isSelected(String route) {
    if (route == '/home') return currentLocation.startsWith('/home');
    if (route == '/profile') {
      return currentLocation.startsWith('/profile');
    }
    if (route == '/admin') {
      return currentLocation.startsWith('/admin');
    }
    return currentLocation.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: DesktopTokens.sidebarDecoration(),
      child: SizedBox(
        width: DesktopTokens.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: DesktopTokens.titleBarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: AppGradients.gold,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Image.asset(
                        ReferenceAssets.appLogo,
                        fit: BoxFit.contain,
                        color: AppColors.primaryDeep,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Text(
                AppLocalizations.of(context)!.splashTagline,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLink extends StatefulWidget {
  const _SidebarLink({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DesktopSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarLink> createState() => _SidebarLinkState();
}

class _SidebarLinkState extends State<_SidebarLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final hovered = _hovered && !selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? DesktopTokens.sidebarSelectedBg
                    : hovered
                        ? DesktopTokens.hoverBg
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? Border(
                        left: BorderSide(
                          color: AppColors.referencePrimary,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? widget.item.selectedIcon : widget.item.icon,
                    size: 18,
                    color: selected
                        ? AppColors.referencePrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.referencePrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.item.shortcut != null)
                    Text(
                      widget.item.shortcut!,
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
      ),
    );
  }
}

List<DesktopSidebarItem> defaultDesktopSidebarItems(
  AppLocalizations l10n, {
  bool isAdmin = false,
  bool canManageBooks = false,
}) {
  return [
    DesktopSidebarItem(
      route: '/home',
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: l10n.navHome,
      shortcut: '⌘1',
    ),
    DesktopSidebarItem(
      route: '/downloads',
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
      label: l10n.downloadsPageTitle,
      shortcut: '⌘2',
    ),
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
      shortcut: '⌘3',
    ),
    DesktopSidebarItem(
      route: '/profile',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: l10n.navProfile,
      shortcut: '⌘4',
    ),
    if (isAdmin || canManageBooks)
      DesktopSidebarItem(
        route: '/admin/books',
        icon: isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.menu_book_outlined,
        selectedIcon: isAdmin
            ? Icons.admin_panel_settings_rounded
            : Icons.menu_book_rounded,
        label: isAdmin ? l10n.adminHomeTitle : l10n.authorMyBooks,
        shortcut: '⌘5',
      ),
    if (isAdmin)
      DesktopSidebarItem(
        route: '/admin/payments',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.adminPaymentsTitle,
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
          const _DesktopNavIntent('/downloads'),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3):
          const _DesktopNavIntent('/settings'),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit4):
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