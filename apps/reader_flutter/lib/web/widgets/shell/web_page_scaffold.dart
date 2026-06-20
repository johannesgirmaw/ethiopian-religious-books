import 'package:flutter/material.dart';

import '../../design/web_tokens.dart';
import '../../layout/web_content_frame.dart';

/// Standard page wrapper for web shell routes: fills canvas and centers content.
class WebPageScaffold extends StatelessWidget {
  const WebPageScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WebTokens.canvasBg,
      child: SizedBox.expand(
        child: WebContentFrame(child: body),
      ),
    );
  }
}
