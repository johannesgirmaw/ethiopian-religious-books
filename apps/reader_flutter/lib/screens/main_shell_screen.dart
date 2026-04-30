import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.child});

  final Widget child;

  static const _tabs = <String>['/home', '/library', '/account'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      // Keep shell content mounted directly; wrapping route trees in AnimatedSwitcher
      // can retain two navigator subtrees simultaneously and trigger GlobalKey collisions.
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        animationDuration: AppMotion.medium,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books_rounded),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.navAccount,
          ),
        ],
        onDestinationSelected: (newIndex) {
          context.go(_tabs[newIndex]);
        },
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/account')) return 2;
    if (location.startsWith('/library')) return 1;
    return 0;
  }
}
