import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'desktop_app_shell.dart';
import 'desktop_sidebar.dart';

/// Shell routes use [DesktopAppShell] with persistent sidebar navigation.
class DesktopShellScaffold extends ConsumerWidget {
  const DesktopShellScaffold({
    super.key,
    required this.appTitle,
    required this.child,
  });

  final String appTitle;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final isAdminList = location.startsWith('/admin/books') &&
        !location.contains('/edit') &&
        !location.endsWith('/new');

    return DesktopAppShell(
      currentLocation: location,
      sidebarItems: desktopSidebarItemsFor(ref, l10n),
      appTitle: appTitle,
      breadcrumb: isAdminList ? l10n.adminBooksListTitle : null,
      onBack: isAdminList
          ? () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            }
          : null,
      child: child,
    );
  }
}
