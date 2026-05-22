import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../widgets/liquid_glass_nav_bar.dart';
import '../widgets/shell_scope.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, required this.child});

  final Widget child;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _tabs = <String>['/home', '/library', '/profile'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return ShellScope(
      openDrawer: () {
        _scaffoldKey.currentState?.openDrawer();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: LiquidGlassNavBar.bottomInset,
              child: widget.child,
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
                    icon: Icons.library_books_outlined,
                    selectedIcon: Icons.library_books_rounded,
                    label: l10n.navBrowse,
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
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return 2;
    }
    if (location.startsWith('/library')) return 1;
    if (location.startsWith('/downloads')) return 0;
    return 0;
  }
}
