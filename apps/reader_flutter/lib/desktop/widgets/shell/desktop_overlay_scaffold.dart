import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'desktop_app_shell.dart';
import 'desktop_sidebar.dart';

/// Overlay pages keep the sidebar and show a title bar.
class DesktopOverlayScaffold extends ConsumerWidget {
  const DesktopOverlayScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentLocation,
    this.actions,
    this.onBack,
  });

  final String title;
  final Widget body;
  final String currentLocation;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopAppShell(
      currentLocation: currentLocation,
      sidebarItems: desktopSidebarItemsFor(ref, l10n),
      breadcrumb: title,
      actions: actions,
      onBack: onBack,
      child: body,
    );
  }
}
