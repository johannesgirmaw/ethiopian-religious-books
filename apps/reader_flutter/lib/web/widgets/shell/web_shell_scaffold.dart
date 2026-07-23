import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'web_app_shell.dart';
import 'web_sidebar.dart';

/// Shell routes use [WebAppShell] with persistent sidebar navigation.
class WebShellScaffold extends ConsumerWidget {
  const WebShellScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final isAdminList = location.startsWith('/admin/books') &&
        !location.contains('/edit') &&
        !location.endsWith('/new');

    return WebAppShell(
      currentLocation: location,
      sidebarItems: webSidebarItemsFor(ref, l10n),
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
