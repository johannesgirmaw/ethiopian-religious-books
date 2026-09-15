import 'package:flutter/material.dart';

import '../../design/desktop_tokens.dart';
import '../../layout/desktop_layout_scope.dart';
import 'desktop_sidebar.dart';
import 'desktop_top_header.dart';

/// Sidebar + persistent header + main canvas for shell routes.
class DesktopAppShell extends StatelessWidget {
  const DesktopAppShell({
    super.key,
    required this.currentLocation,
    required this.sidebarItems,
    required this.child,
    this.breadcrumb,
    this.actions,
    this.onBack,
  });

  final String currentLocation;
  final List<DesktopSidebarItem> sidebarItems;
  final Widget child;
  final String? breadcrumb;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DesktopNavShortcuts(
      items: sidebarItems,
      child: Scaffold(
        backgroundColor: DesktopTokens.canvasBg,
        body: DesktopLayoutScopeBuilder(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopSidebar(
                currentLocation: currentLocation,
                items: sidebarItems,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopTopHeader(
                      breadcrumb: breadcrumb,
                      actions: actions,
                      onBack: onBack,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
