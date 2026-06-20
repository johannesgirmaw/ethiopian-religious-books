import 'package:flutter/material.dart';

import '../design/desktop_tokens.dart';

/// Fills the main content area and optionally caps width on very wide monitors.
class DesktopContentFrame extends StatelessWidget {
  const DesktopContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.clamp(0.0, DesktopTokens.contentMaxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null,
            child: child,
          ),
        );
      },
    );
  }
}
