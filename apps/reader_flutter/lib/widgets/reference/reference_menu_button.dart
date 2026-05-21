import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../shell_scope.dart';

/// Standard offsets for the drawer menu (below status bar, aligned with AppBar).
class ReferenceMenuLayout {
  ReferenceMenuLayout._();

  /// Top edge of the menu hit target (status bar + toolbar margin).
  static double top(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 4;
  }

  static const double left = 4;

  /// Material toolbar row height (excluding status bar).
  static const double toolbarHeight = kToolbarHeight;
}

/// Drawer menu control — icon only, no background decoration.
class ReferenceMenuButton extends StatelessWidget {
  const ReferenceMenuButton({
    super.key,
    this.color,
    this.iconSize = 24,
  });

  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ??
        Theme.of(context).iconTheme.color ??
        AppColors.textPrimary;

    return IconButton(
      icon: Icon(Icons.menu_rounded, size: iconSize),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: ShellScope.openDrawerOf(context),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: iconColor,
        shadowColor: Colors.transparent,
        elevation: 0,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
