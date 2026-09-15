import 'package:flutter/material.dart';

import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';
import 'web_sidebar.dart';
import 'web_top_header.dart';

/// Sidebar + persistent header + main canvas for shell routes.
class WebAppShell extends StatelessWidget {
  const WebAppShell({
    super.key,
    required this.currentLocation,
    required this.sidebarItems,
    required this.child,
    this.breadcrumb,
    this.actions,
    this.onBack,
  });

  final String currentLocation;
  final List<WebSidebarItem> sidebarItems;
  final Widget child;
  final String? breadcrumb;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebTokens.canvasBg,
      body: AppLayoutScopeBuilder(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebSidebar(
              currentLocation: currentLocation,
              items: sidebarItems,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WebTopHeader(
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
    );
  }
}
