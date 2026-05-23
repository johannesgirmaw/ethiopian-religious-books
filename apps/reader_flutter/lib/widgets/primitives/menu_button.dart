import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../shell_scope.dart';

/// Standard offsets for the drawer menu (below status bar, aligned with AppBar).
class AppMenuLayout {
  AppMenuLayout._();

  static double top(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 4;
  }

  static const double left = 4;
  static const double toolbarHeight = kToolbarHeight;
}

@Deprecated('Use AppMenuLayout')
typedef ReferenceMenuLayout = AppMenuLayout;

/// Drawer menu control.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    super.key,
    this.color,
    this.iconSize = 22,
    this.onDark = false,
  });

  /// High-contrast frosted control for [AppGreetingCard] and other dark surfaces.
  const AppMenuButton.onDark({
    super.key,
    this.iconSize = 22,
  })  : color = Colors.white,
        onDark = true;

  final Color? color;
  final double iconSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final openDrawer = ShellScope.openDrawerOf(context);
    final tooltip = MaterialLocalizations.of(context).openAppDrawerTooltip;

    if (onDark) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openDrawer,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.menu_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final iconColor = color ??
        Theme.of(context).iconTheme.color ??
        AppColors.textPrimary;

    return IconButton(
      icon: Icon(Icons.menu_rounded, size: iconSize, color: iconColor),
      tooltip: tooltip,
      onPressed: openDrawer,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: iconColor,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

@Deprecated('Use AppMenuButton')
typedef ReferenceMenuButton = AppMenuButton;
