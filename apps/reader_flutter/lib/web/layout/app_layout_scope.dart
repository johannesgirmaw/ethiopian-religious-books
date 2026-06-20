import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../design/web_tokens.dart';

enum AppLayoutTier {
  compact,
  medium,
  expanded,
}

AppLayoutTier tierForWidth(double width) {
  if (width >= WebTokens.expandedBreakpoint) {
    return AppLayoutTier.expanded;
  }
  if (width >= WebTokens.compactBreakpoint) {
    return AppLayoutTier.medium;
  }
  return AppLayoutTier.compact;
}

bool useWebShell(BuildContext context) {
  if (!kIsWeb) return false;
  final scoped = AppLayoutScope.maybeOf(context);
  final width = (scoped != null && scoped.width > 0)
      ? scoped.width
      : MediaQuery.sizeOf(context).width;
  return tierForWidth(width) != AppLayoutTier.compact;
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    super.key,
    required this.tier,
    required this.width,
    required super.child,
  });

  final AppLayoutTier tier;
  final double width;

  static AppLayoutTier tierOf(BuildContext context) {
    return maybeOf(context)?.tier ?? AppLayoutTier.compact;
  }

  static double widthOf(BuildContext context) {
    return maybeOf(context)?.width ?? 0;
  }

  static AppLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
  }

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) {
    return tier != oldWidget.tier || width != oldWidget.width;
  }
}

/// Provides [AppLayoutScope] from the current max width constraint.
class AppLayoutScopeBuilder extends StatelessWidget {
  const AppLayoutScopeBuilder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AppLayoutScope(
          tier: tierForWidth(width),
          width: width,
          child: child,
        );
      },
    );
  }
}
