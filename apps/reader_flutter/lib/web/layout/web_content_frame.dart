import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/web_tokens.dart';

/// Full-bleed shell page canvas with bounded height for nested scroll views.
///
/// Width fills the main pane so the scrollbar sits on the pane edge. Content
/// stays capped via [WebContentInsets.sideGutter] + [WebTokens.pagePaddingOf].
class WebContentFrame extends StatelessWidget {
  const WebContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final hasHeight = height.isFinite && height > 0;
        // Do not mount page bodies at 0px. Opaque overlays offstage this
        // route with zero constraints; a 0-height scroll viewport can fail
        // to recover when the overlay is popped.
        if (!hasHeight) {
          return const SizedBox.expand();
        }
        final paneWidth = constraints.maxWidth;
        final contentWidth =
            math.min(paneWidth, WebTokens.maxContentWidth);
        final sideGutter = math.max(0.0, (paneWidth - contentWidth) / 2);
        return SizedBox(
          width: paneWidth,
          height: height,
          child: WebContentInsets(
            sideGutter: sideGutter,
            child: child,
          ),
        );
      },
    );
  }
}
