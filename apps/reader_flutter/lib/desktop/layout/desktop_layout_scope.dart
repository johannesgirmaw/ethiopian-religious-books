import 'package:flutter/widgets.dart';

import '../design/desktop_tokens.dart';

/// Provides desktop layout constraints (window width tiers).
class DesktopLayoutScope extends InheritedWidget {
  const DesktopLayoutScope({
    super.key,
    required this.tier,
    required this.width,
    required super.child,
  });

  final DesktopLayoutTier tier;
  final double width;

  static DesktopLayoutTier tierOf(BuildContext context) {
    return maybeOf(context)?.tier ?? DesktopLayoutTier.medium;
  }

  static double widthOf(BuildContext context) {
    return maybeOf(context)?.width ?? 0;
  }

  static DesktopLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopLayoutScope>();
  }

  @override
  bool updateShouldNotify(DesktopLayoutScope oldWidget) {
    return tier != oldWidget.tier || width != oldWidget.width;
  }
}

class DesktopLayoutScopeBuilder extends StatelessWidget {
  const DesktopLayoutScopeBuilder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return DesktopLayoutScope(
          tier: DesktopTokens.tierForWidth(width),
          width: width,
          child: child,
        );
      },
    );
  }
}
