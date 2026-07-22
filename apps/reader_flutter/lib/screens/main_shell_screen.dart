import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_shell_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../providers/nav_visibility_providers.dart';
import '../providers/session_notifier.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_shell_scaffold.dart';
import '../mobile/widgets/shell/liquid_glass_nav_bar.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    final isAdmin = user?.isPlatformAdmin ?? false;
    final canManageBooks = user?.canManageBooks ?? false;

    if (useWebShell(context)) {
      return WebShellScaffold(
        appTitle: l10n.appTitle,
        child: child,
      );
    }

    if (useDesktopShell(context)) {
      return DesktopShellScaffold(
        appTitle: l10n.appTitle,
        child: child,
      );
    }

    // Purchases tab only appears once the user has a transaction to look at.
    final hasPurchases = ref.watch(hasPurchasesProvider).valueOrNull ?? false;
    final tabs = <String>[
      '/home',
      if (hasPurchases) '/purchases',
      '/profile',
      if (canManageBooks) '/admin/books',
    ];
    final index = _indexFor(location, tabs);

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: LiquidGlassNavBar.bottomInset,
            child: child,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassNavBar(
              selectedIndex: index,
              onSelected: (newIndex) => context.go(tabs[newIndex]),
              items: [
                LiquidNavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore_rounded,
                  label: l10n.navHome,
                ),
                if (hasPurchases)
                  LiquidNavItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long_rounded,
                    label: l10n.navPurchases,
                  ),
                LiquidNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: l10n.navProfile,
                ),
                if (canManageBooks)
                  LiquidNavItem(
                    icon: Icons.menu_book_outlined,
                    selectedIcon: Icons.menu_book_rounded,
                    label: isAdmin ? l10n.adminBooksMenuTitle : l10n.authorMyBooks,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _indexFor(String location, List<String> tabs) {
    int find(String route) {
      final i = tabs.indexOf(route);
      return i < 0 ? 0 : i;
    }

    if (location.startsWith('/admin')) return find('/admin/books');
    if (location.startsWith('/purchases')) return find('/purchases');
    // Settings is merged into the Profile tab.
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return find('/profile');
    }
    // /home, /downloads, and /bible map to the Home tab.
    if (location.startsWith('/bible') || location.startsWith('/downloads')) {
      return find('/home');
    }
    return find('/home');
  }
}
