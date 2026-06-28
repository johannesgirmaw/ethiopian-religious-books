import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/desktop_tokens.dart';
import 'desktop_auth_layout.dart';

/// Desktop auth shell: fixed brand panel + animated form column.
class DesktopAuthShell extends ConsumerWidget {
  const DesktopAuthShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeKey = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: DesktopTokens.canvasBg,
      body: Row(
        children: [
          const Expanded(
            flex: 5,
            child: DesktopAuthBrandPanel(),
          ),
          Expanded(
            flex: 4,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: KeyedSubtree(
                key: ValueKey(routeKey),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
