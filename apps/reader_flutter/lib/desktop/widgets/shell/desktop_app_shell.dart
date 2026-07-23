import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../design/desktop_tokens.dart';
import '../../layout/desktop_layout_scope.dart';
import 'desktop_sidebar.dart';

/// Sidebar + scrollable main canvas for shell routes.
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
                    if (breadcrumb != null)
                      _TitleBar(
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
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
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
        color: DesktopTokens.surfaceBg,
        border: Border(bottom: BorderSide(color: DesktopTokens.borderColor)),
      ),
      child: SizedBox(
        height: DesktopTokens.titleBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    fontSize: 13,
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
    );
  }
}
