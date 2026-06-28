import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';
import 'web_auth_layout.dart';

/// Web auth shell: fixed brand panel + animated form column on expanded layouts.
class WebAuthShell extends ConsumerWidget {
  const WebAuthShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLayoutScopeBuilder(
      child: Builder(
        builder: (context) {
          final isExpanded =
              AppLayoutScope.tierOf(context) == AppLayoutTier.expanded;
          if (!isExpanded) return child;

          final routeKey = GoRouterState.of(context).matchedLocation;

          return Scaffold(
            backgroundColor: WebTokens.canvasBg,
            body: SafeArea(
              child: Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: WebAuthBrandPanel(),
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
            ),
          );
        },
      ),
    );
  }
}
