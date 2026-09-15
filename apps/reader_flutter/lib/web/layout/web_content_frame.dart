import 'package:flutter/material.dart';

import '../design/web_tokens.dart';

/// Centers shell page content on wide web viewports with bounded height.
class WebContentFrame extends StatelessWidget {
  const WebContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, WebTokens.maxContentWidth);
        final height = constraints.maxHeight;
        final hasHeight = height.isFinite && height > 0;
        // Do not mount page bodies at 0px. Opaque overlays offstage this
        // route with zero constraints; a 0-height scroll viewport can fail
        // to recover when the overlay is popped.
        if (!hasHeight) {
          return const SizedBox.expand();
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        );
      },
    );
  }
}
