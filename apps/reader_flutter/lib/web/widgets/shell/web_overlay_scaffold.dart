import 'package:flutter/material.dart';

import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';
import 'web_app_shell.dart';
import 'web_sidebar.dart';

/// Overlay pages keep the sidebar and show a breadcrumb bar.
class WebOverlayScaffold extends StatelessWidget {
  const WebOverlayScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentLocation,
    required this.sidebarItems,
    required this.appTitle,
    this.actions,
    this.onBack,
  });

  final String title;
  final Widget body;
  final String currentLocation;
  final List<WebSidebarItem> sidebarItems;
  final String appTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return WebAppShell(
      currentLocation: currentLocation,
      sidebarItems: sidebarItems,
      appTitle: appTitle,
      breadcrumb: title,
      actions: actions,
      child: body,
    );
  }
}
