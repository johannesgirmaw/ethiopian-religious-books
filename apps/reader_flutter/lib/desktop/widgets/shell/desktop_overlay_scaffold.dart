import 'package:flutter/material.dart';

import 'desktop_app_shell.dart';
import 'desktop_sidebar.dart';

/// Overlay pages keep the sidebar and show a title bar.
class DesktopOverlayScaffold extends StatelessWidget {
  const DesktopOverlayScaffold({
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
  final List<DesktopSidebarItem> sidebarItems;
  final String appTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DesktopAppShell(
      currentLocation: currentLocation,
      sidebarItems: sidebarItems,
      appTitle: appTitle,
      breadcrumb: title,
      actions: actions,
      onBack: onBack,
      child: body,
    );
  }
}
