import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_shell_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_shell_scaffold.dart';
import '../widgets/liquid_glass_nav_bar.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.child});

  final Widget child;

  static const _tabs = <String>['/home', '/settings', '/profile'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

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
              onSelected: (newIndex) => context.go(_tabs[newIndex]),
              items: [
                LiquidNavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore_rounded,
                  label: l10n.navHome,
                ),
                LiquidNavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: l10n.navSettings,
                ),
                LiquidNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: l10n.navProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _indexFor(String location) {
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/settings')) return 1;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/downloads')) return 0;
    return 0;
  }
}
