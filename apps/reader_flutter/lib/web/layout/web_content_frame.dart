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
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
