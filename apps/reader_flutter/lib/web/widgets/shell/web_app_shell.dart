import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';
import 'web_sidebar.dart';

/// Sidebar + scrollable main canvas for shell routes.
class WebAppShell extends StatelessWidget {
  const WebAppShell({
    super.key,
    required this.currentLocation,
    required this.sidebarItems,
    required this.appTitle,
    required this.child,
    this.breadcrumb,
    this.actions,
    this.onBack,
  });

  final String currentLocation;
  final List<WebSidebarItem> sidebarItems;
  final String appTitle;
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
              appTitle: appTitle,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (breadcrumb != null)
                    _BreadcrumbBar(
                      label: breadcrumb!,
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

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.label,
    this.actions,
    this.onBack,
  });

  final String label;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WebTokens.surfaceBg,
        border: Border(bottom: BorderSide(color: WebTokens.borderColor)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: WebTokens.navHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: onBack,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
