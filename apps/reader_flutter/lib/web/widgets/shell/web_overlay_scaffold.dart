import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'web_app_shell.dart';
import 'web_sidebar.dart';

/// Overlay pages keep the sidebar and show a breadcrumb bar.
class WebOverlayScaffold extends ConsumerWidget {
  const WebOverlayScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentLocation,
    required this.appTitle,
    this.actions,
    this.onBack,
  });

  final String title;
  final Widget body;
  final String currentLocation;
  final String appTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return WebAppShell(
      currentLocation: currentLocation,
      sidebarItems: webSidebarItemsFor(ref, l10n),
      appTitle: appTitle,
      breadcrumb: title,
      actions: actions,
      onBack: onBack,
      child: body,
    );
  }
}
